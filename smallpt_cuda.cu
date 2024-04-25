//
// smallpt, a Path Tracer by Kevin Beason, 2008 
// Make : g++ -O3 smallpt_serial.cpp -o smallpt_serial
//        Remove "-fopenmp" for g++ version < 4.2
// Usage: time ./smallpt_serial 5000 && xv image.ppm

#include <math.h>   
#include <stdlib.h> 
#include <stdio.h> 
#include <curand_kernel.h>

#include "resource/rdtsc.h"

using namespace std;

#define MAX_THREADS 2048
#define MXAA_W 2
#define MXAA_H 2
#define IMG_W 1024
#define IMG_H 512

struct Vec
{                 
  double x, y, z; // position, also color (r,g,b)

  __host__ __device__ Vec(double x_ = 0, double y_ = 0, double z_ = 0) { x = x_; y = y_; z = z_; }
  __host__ __device__ Vec operator+(const Vec &b) const { return Vec(x + b.x, y + b.y, z + b.z); }
  __host__ __device__ Vec operator-(const Vec &b) const { return Vec(x - b.x, y - b.y, z - b.z); }
  __host__ __device__ Vec operator*(double b) const { return Vec(x * b, y * b, z * b); }
  __host__ __device__ Vec mult(const Vec &b) const { return Vec(x * b.x, y * b.y, z * b.z); }
  __host__ __device__ Vec &norm() { return *this = *this * (1 / sqrt(x * x + y * y + z * z)); }
  __host__ __device__ double dot(const Vec &b) const { return x * b.x + y * b.y + z * b.z; } // cross:
  __host__ __device__ Vec operator%(Vec &b) { return Vec(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x); }
};

struct Ray
{
  Vec o, d;
  __device__ Ray(Vec o_, Vec d_) : o(o_), d(d_) {}
};

enum Refl_t
{
  DIFF,
  SPEC,
  REFR
}; // material types, used in radiance()

struct Sphere
{
  double rad;  // radius
  Vec p, e, c; // position, emission, color
  Refl_t refl; // reflection type (DIFFuse, SPECular, REFRactive)

  __device__ Sphere(double rad_, Vec p_, Vec e_, Vec c_, Refl_t refl_) : rad(rad_), p(p_), e(e_), c(c_), refl(refl_) {}

  __device__ double intersect(const Ray &r) const // returns distance, 0 if nohit
  {                   
    Vec op = p - r.o; // Solve t^2*d.d + 2*t*(o-p).d + (o-p).(o-p)-R^2 = 0
    double t, eps = 1e-4, b = op.dot(r.d), det = b * b - op.dot(op) + rad * rad;
    if (det < 0)
      return 0;
    else
      det = sqrt(det);
    return (t = b - det) > eps ? t : ((t = b + det) > eps ? t : 0);
  }
};

// Cornelbox -------------------------------------------------------------------
Sphere spheres[] = {
    // Scene: radius, position, emission, color, material
    Sphere(1e5, Vec(1e5 + 1, 40.8, 81.6), Vec(), Vec(.75, .25, .25), DIFF),   // Left
    Sphere(1e5, Vec(-1e5 + 99, 40.8, 81.6), Vec(), Vec(.25, .25, .75), DIFF), // Rght
    Sphere(1e5, Vec(50, 40.8, 1e5), Vec(), Vec(.75, .75, .75), DIFF),         // Back
    Sphere(1e5, Vec(50, 40.8, -1e5 + 170), Vec(), Vec(), DIFF),               // Frnt
    Sphere(1e5, Vec(50, 1e5, 81.6), Vec(), Vec(.75, .75, .75), DIFF),         // Botm
    Sphere(1e5, Vec(50, -1e5 + 81.6, 81.6), Vec(), Vec(.75, .75, .75), DIFF), // Top
    Sphere(16.5, Vec(27, 16.5, 47), Vec(), Vec(1, 1, 1) * .999, SPEC),        // Mirr
    Sphere(16.5, Vec(73, 16.5, 78), Vec(), Vec(1, 1, 1) * .999, REFR),        // Glas
    Sphere(600, Vec(50, 681.6 - .27, 81.6), Vec(12, 12, 12), Vec(), DIFF)     // Lite
};

// Sky -------------------------------------------------------------------------
// Vec Cen(50,40.8,-860);
// Sphere spheres[] = {//Scene: radius, position, emission, color, material
//   // center 50 40.8 62
//   // floor 0
//   // back  0

//    Sphere(1600, Vec(1,0,2)*3000, Vec(1,.9,.8)*1.2e1*1.56*2,Vec(), DIFF), // sun
//    Sphere(1560, Vec(1,0,2)*3500,Vec(1,.5,.05)*4.8e1*1.56*2, Vec(),  DIFF), // horizon sun2
// //   Sphere(10000,Cen+Vec(0,0,-200), Vec(0.0627, 0.188, 0.569)*6e-2*8, Vec(.7,.7,1)*.25,  DIFF), // sky
//    Sphere(10000,Cen+Vec(0,0,-200), Vec(0.00063842, 0.02001478, 0.28923243)*6e-2*8, Vec(.7,.7,1)*.25,  DIFF), // sky

//   Sphere(100000, Vec(50, -100000, 0),  Vec(),Vec(.3,.3,.3),DIFF), // grnd
//   Sphere(110000, Vec(50, -110048.5, 0),  Vec(.9,.5,.05)*4,Vec(),DIFF),// horizon brightener
//   Sphere(4e4, Vec(50, -4e4-30, -3000),  Vec(),Vec(.2,.2,.2),DIFF),// mountains
// //  Sphere(3.99e4, Vec(50, -3.99e4+20.045, -3000),  Vec(),Vec(.7,.7,.7),DIFF),// mountains snow

//    Sphere(26.5,Vec(22,26.5,42),   Vec(),Vec(1,1,1)*.596, SPEC), // white Mirr
//    Sphere(13,Vec(75,13,82),   Vec(),Vec(.96,.96,.96)*.96, REFR),// Glas
//   Sphere(22,Vec(87,22,24),   Vec(),Vec(.6,.6,.6)*.696, REFR)    // Glas2
// };

// Nightsky ---------------------------------------------------------------------
// Sphere spheres[] = {//Scene: radius, position, emission, color, material
//   // center 50 40.8 62
//   // floor 0
//   // back  0
//   //     rad       pos                   emis           col     refl
// //  Sphere(1e3,   Vec(1,1,-2)*1e4,    Vec(1,1,1)*5e2,     Vec(), DIFF), // moon
// //  Sphere(3e2,   Vec(.6,.2,-2)*1e4,    Vec(1,1,1)*5e3,     Vec(), DIFF), //
// //  moon

//   Sphere(2.5e3,   Vec(.82,.92,-2)*1e4,    Vec(1,1,1)*.8e2,     Vec(), DIFF), // moon

// //  Sphere(2.5e4, Vec(50, 0, 0),     Vec(1,1,1)*1e-3,    Vec(.2,.2,1)*0.0075, DIFF), // sky
// //  Sphere(2.5e4, Vec(50, 0, 0),  Vec(0.114, 0.133, 0.212)*1e-2,  Vec(.216,.384,1)*0.0007, DIFF), // sky

//   Sphere(2.5e4, Vec(50, 0, 0),  Vec(0.114, 0.133, 0.212)*1e-2,  Vec(.216,.384,1)*0.003, DIFF), // sky

//   Sphere(5e0,   Vec(-.2,0.16,-1)*1e4, Vec(1.00, 0.843, 0.698)*1e2,   Vec(), DIFF),  // star
//   Sphere(5e0,   Vec(0,  0.18,-1)*1e4, Vec(1.00, 0.851, 0.710)*1e2,  Vec(), DIFF),  // star
//   Sphere(5e0,   Vec(.3, 0.15,-1)*1e4, Vec(0.671, 0.780, 1.00)*1e2,   Vec(), DIFF),  // star
//   Sphere(3.5e4,   Vec(600,-3.5e4+1, 300), Vec(),   Vec(.6,.8,1)*.01,  REFR),   //pool
//   Sphere(5e4,   Vec(-500,-5e4+0, 0),   Vec(),      Vec(1,1,1)*.35,  DIFF),    //hill
//   Sphere(16.5,  Vec(27,0,47),         Vec(),              Vec(1,1,1)*.33, DIFF), //hut
//   Sphere(7,     Vec(27+8*sqrt(2),0,47+8*sqrt(2)),Vec(),  Vec(1,1,1)*.33,  DIFF), //door
//   Sphere(500,   Vec(-1e3,-300,-3e3), Vec(),  Vec(1,1,1)*.351,    DIFF),  //mnt
//   Sphere(830,   Vec(0,   -500,-3e3), Vec(),  Vec(1,1,1)*.354,    DIFF),  //mnt
//   Sphere(490,  Vec(1e3,  -300,-3e3), Vec(),  Vec(1,1,1)*.352,    DIFF),  //mnt
// };

__host__ __device__ inline double clamp(double x) { return x < 0 ? 0 : x > 1 ? 1: x; }

__host__ __device__ inline int toInt(double x) { return int(pow(clamp(x), 1 / 2.2) * 255 + .5); }

__device__ inline bool intersect(const Ray &r, double &t, int &id, Sphere* spheres)
{
  double n = sizeof(spheres) / sizeof(Sphere), d, inf = t = 1e20;
  for (int i = int(n); i--;)
    if ((d = spheres[i].intersect(r)) && d < t)
    {
      t = d;
      id = i;
    }
  return t < inf;
}

__device__ Vec radiance(const Ray &r, int depth, curandState *state, Sphere* spheres)
{
  double t;   // distance to intersection
  int id = 0; // id of intersected object

  if (!intersect(r, t, id, spheres))
    return Vec();                  // if miss, return black

  const Sphere &obj = spheres[id]; // the hit object
  Vec x = r.o + r.d * t;
  Vec n = (x - obj.p).norm();
  Vec nl = n.dot(r.d) < 0 ? n : n * -1;
  Vec f = obj.c;

  double p = f.x > f.y && f.x > f.z ? f.x : f.y > f.z ? f.y : f.z; // max refl

  if (++depth > 5)
    if (curand_uniform(state) < p)
      f = f * (1 / p);
    else
      return obj.e; // R.R.

  if (obj.refl == DIFF) // Ideal DIFFUSE reflection
  { 
   
    double r1 = 2 * M_PI * curand_uniform(state), r2 = curand_uniform(state), r2s = sqrt(r2);
    Vec w = nl;
    Vec u = ((fabs(w.x) > .1 ? Vec(0, 1) : Vec(1)) % w).norm();
    Vec v = w % u;
    Vec d = (u * cos(r1) * r2s + v * sin(r1) * r2s + w * sqrt(1 - r2)).norm();
    return obj.e + f.mult(radiance(Ray(x, d), depth, state, spheres));
  }
  else if (obj.refl == SPEC) // Ideal SPECULAR reflection
  { 
    return obj.e + f.mult(radiance(Ray(x, r.d - n * 2 * n.dot(r.d)), depth, state, spheres));
  }

  Ray reflRay(x, r.d - n * 2 * n.dot(r.d)); // Ideal dielectric REFRACTION

  bool into = n.dot(nl) > 0;                // Ray from outside going in?

  double nc = 1, nt = 1.5;
  double nnt = into ? nc / nt : nt / nc;
  double ddn = r.d.dot(nl), cos2t;

  if ((cos2t = 1 - nnt * nnt * (1 - ddn * ddn)) < 0) // Total internal reflection
    return obj.e + f.mult(radiance(reflRay, depth, state, spheres));

  Vec tdir = (r.d * nnt - n * ((into ? 1 : -1) * (ddn * nnt + sqrt(cos2t)))).norm();

  double a = nt - nc;
  double b = nt + nc;
  double R0 = a * a / (b * b);
  double c = 1 - (into ? -ddn : tdir.dot(n));
  double Re = R0 + (1 - R0) * c * c * c * c * c;
  double Tr = 1 - Re;
  double P = .25 + .5 * Re;
  double RP = Re / P;
  double TP = Tr / (1 - P);

  return obj.e + f.mult(depth > 2 ? (curand_uniform(state) < P ? // Russian roulette
                                         radiance(reflRay, depth, state, spheres) * RP
                                                     : radiance(Ray(x, tdir), depth, state, spheres) * TP)
                                  : radiance(reflRay, depth, state, spheres) * Re + radiance(Ray(x, tdir), depth, state, spheres) * Tr);
}

// Generated by GPT4.0
__device__ double atomicAddDouble(double* address, double val) { 
    unsigned long long int* address_as_ull =
                              (unsigned long long int*)address;
    unsigned long long int old = *address_as_ull, assumed;

    do {
        assumed = old;
        old = atomicCAS(address_as_ull, assumed,
                __double_as_longlong(val +
                    __longlong_as_double(assumed)));
    } while (assumed != old);
    return __longlong_as_double(old);
}

__device__ void atomicAddVec(Vec *c, Vec v) {
  atomicAddDouble(&c->x, v.x);
  atomicAddDouble(&c->y, v.y);
  atomicAddDouble(&c->z, v.z);
}

__global__ void render (int samples, Vec *c, Sphere* spheres)
{
  Ray cam(Vec(50, 52, 295.6), Vec(0, -0.042612, -1).norm());    // cam pos, dir
  Vec cx = Vec(IMG_W * .5135 / IMG_H);
  Vec cy = (cx % cam.d).norm() * .5135;
  Vec r(0.f);

  int y = blockIdx.x * blockDim.x + threadIdx.x; // horizontal
  int x = blockIdx.y * blockDim.y + threadIdx.y; // vertical

  unsigned short Xi = y * y * y;

  curandState *state;
  cudaMalloc(&state, sizeof(curandState));
  curand_init(Xi, (unsigned long long)(x * IMG_W + y), 0, state); // the seed for the same thread will always 
                                                                  // be the same, but distinct from other threads
  
  for (int sy = 0, i = (IMG_H - y - 1) * IMG_W + x; sy < 2; sy++) { // MXAA rows
    for (int sx = 0; sx < 2; sx++, r = Vec())                       // MXAA cols     
      for (int s = 0; s < samples; ++ s) {                          // Ray samples per MXAA sample

        double r1 = curand_uniform(state);
        double r2 = curand_uniform(state);

        double dx = r1 < 1 ? sqrt(r1) - 1 : 1 - sqrt(2 - r1);
        double dy = r2 < 1 ? sqrt(r2) - 1 : 1 - sqrt(2 - r2);

        Vec d = cx * (((sx + .5 + dx) / 2 + x) / IMG_W - .5) +
                cy * (((sy + .5 + dy) / 2 + y) / IMG_H - .5) + cam.d;

        r = r + radiance(Ray(cam.o + d * 140, d.norm()), 0, state, spheres) * (1. / samples);
      }
    
    // c[i] = c[i] + Vec(clamp(r.x), clamp(r.y), clamp(r.z)) * .25;
    Vec to_add(0.25 * clamp(r.x), 0.25 * clamp(r.y), 0.25 * clamp(r.z));
    atomicAddVec(&c[i], to_add);
  }

}

int main(int argc, char *argv[])
{
  // Host variables
  int w = IMG_W;
  int h = IMG_H;
  int samps = argc == 2 ? atoi(argv[1]) / MXAA_W / MXAA_H : 1;                // # samples
  Vec *result_c = new Vec[w*h];

  // Device variables
  Vec *dev_c;
  cudaMalloc((void**)&dev_c, w * h * sizeof(Vec));
  Sphere* dev_spheres;
  cudaMalloc((void**)&dev_spheres, sizeof(spheres));
  cudaMemcpy(dev_spheres, spheres, sizeof(spheres), cudaMemcpyHostToDevice);

  tsc_counter t0, t1;

  RDTSC(t0);


  // /* // GPU Version
  int max_w = w * MXAA_W;
  int max_h = h * MXAA_H;
  int all_samples = max_w * max_h * samps;

  int threadH = (MAX_THREADS > max_w) ? max_w : MAX_THREADS;
  int threadV = (MAX_THREADS > max_w) ? ceil(MAX_THREADS / max_w) : 1;
  dim3 Threads(threadH, threadV, 1);
  dim3 Blocks(all_samples / threadH / threadV, 1, 1);

  render<<<Blocks, Threads>>>(samps, dev_c, dev_spheres);
  cudaMemcpy(result_c, dev_c, w * h * sizeof(Vec), cudaMemcpyDeviceToHost);

  cudaFree(dev_c);
  cudaFree(dev_spheres);
  // */

  RDTSC(t1);
  printf("\nRendering Time: %lf cycles\n", ((double) COUNTER_DIFF(t1, t0, CYCLES)));
  
  FILE *f = fopen("image.ppm", "w"); // Write image to PPM file.
  fprintf(f, "P3\n%d %d\n%d\n", w, h, 255);
  for (int i = 0; i < w * h; i++)
    fprintf(f, "%d %d %d ", toInt(result_c[i].x), toInt(result_c[i].y), toInt(result_c[i].z));
}
