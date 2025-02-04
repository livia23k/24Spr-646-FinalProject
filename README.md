[TOC]

### How to build the env

​	[Sync between host and server]

​		pull this repo;

​		download the **SFTP** plugin in VS Code;

​		and create .vscode/sftp.json for the project (under /smallpt);

            {  
                "name": "18646",
                "host": "ece017.ece.local.cmu.edu",  
                "protocol": "sftp",  
                "port": 22,  
                "username": "[andrewid]",  
                "remotePath": "private/18646/p1/smallpt",
                "uploadOnSave": true,  
                "downloadOnOpen": true,  
                "ignore": [  
                    ".vscode",  
                    ".git",  
                    ".DS_Store",  
                    "admin"  
                ]  
            }



​	[Access]
​		ssh [andrewid]@ece017.ece.local.cmu.edu
​		cd private/18646/p1/smallpt/



### How to run

    [Build cuda environment]
        make cuda_env
        source ~/.bashrc

    [Compile]
    ​    make all
​    
    [Run]
        make run_serial SPP=[samples_per_pixel]
    ​    make run_omp SPP=[samples_per_pixel]
    ​    make run_cuda SPP=[samples_per_pixel]



### How to replace the scenes

​    refer to /smallpt/resource/scene.txt, choose what we want \
​    and replace the corresponding code (Sphere spheres[] = {}) in smallpt.cpp



### How to set OpenMP parameters

[OMP Info Display]
    export OMP_DISPLAY_ENV=true

[Thread Num]
    export OMP_NUM_THREADS=32

[Thread Affinity]
    export OMP_PROC_BIND=spread
    export OMP_PLACES=threads


### Original Readme (from Smallpt)

TITLE

smallpt: Global Illumination in 99 lines of C++

CREDITS

Author: Kevin Beason (kevin.beason [at] gmail.com)
Date: 10/11/2008

SUMMARY

smallpt is a small Monte Carlo path tracer, and generates a single image of a
modified Cornell box rendered with full global illumination (GI). It does this
by solving the rendering equation, including ideal Lambertian, specular, and
dielectric reflection, area lights, anti-aliasing, importance sampling, and
multi-threading. It is only 99 lines of C++, but illustrates photo realistic
rendering in a correct, and concise manner.

DESCRIPTION

The source code for a small program that path traces a simple Cornell box and
produces accurate results in a terse implementation is given, which provides an
educational example to new graphics students (and seasoned alike), and yields a
ground truth image, all in an easy to read package. Never before has a correct,
complete, and functioning path tracer been presented so succinctly. Readers
will see ray-sphere intersection, Monte Carlo path tracing, Russian roulette,
importance sampling, anti-aliasing, and OpenMP multi-threading in a concrete
working example, which may be read from beginning to end in a single
sitting. The program compiles with GCC 4.2 down to a 16k executable and
produces a 1024x768 resolution image using 5000 paths in 2 hours on an Intel
Core 2 Quad machine. With slight modifications (smallpt4k.cpp) the code compiles to
under 4KB.

FEATURES

* Global illumination
* Unbiased Monte Carlo path tracing
* Cornell box scene description
* Ray-sphere intersection
* Soft shadows from diffuse luminaire
* Specular, Diffuse, and Glass BRDFs
* Cosine importance sampling of the hemisphere for diffuse reflection
* Russian roulette for path termination
* Russian roulette for selecting reflection or refraction for glass BRDF
* Antialiasing via super-sampling with importance-sampled tent distribution,
  and 2x2 subpixels
* Automatic multi-threading using OpenMP
* Less than 100 lines of 72-column code
* With provided code changes, can compile to 4K binary

BUILDING

There are two versions of smallpt. The basic version is called "smallpt"
(smallpt.cpp), and is 99 lines. A second version, "smallpt4k" (smallpt4k.cpp),
is 102 lines but compiles to 4K instead of 16KB. It is just a
proof-of-concept. They compute slightly different images due to compiler optimization differences.
The 4 KB version takes 30% longer.

1) Modify top of Makefile to select the correct compiler.
2) "make smallpt" (This builds both the regular version)
3) "make smallpt4k"  (This builds the 4K version. Requires sstrip, see Makefile.)

USAGE

The program takes one argument, the number of samples per pixel. This value
must be greater than 4 to accommodate the 2x2 subpixel grid. For example,
the included reference image was generated with:

     time ./smallpt 5000

This took 124 minutes (2 hours) on a Intel Core 2 Quad Q6600 2.4GHz machine
running Kubuntu Linux (32-bit Gutsy).

The tiny version takes no arguments (5000 samples/pixel is hard coded):

    time ./smallpt4k

Compilation requires gzip and ELFkicker's sstrip command. See the Makefile for
details. It executes in slightly longer time, and yields a slightly different
image due to compiler optimizations differences.

The time command tells you how long the render takes and is optional. You can
view the image with most any image viewer. For example, if you have ImageMagick
installed:

    display image.ppm

MORE INFO

MINILIGHT - a minimal global illumination renderer, by Harrison Ainsworth
A similar, earlier project. More general but also larger (100x). The site has
some good information on Monte Carlo path tracing. Instead of repeating it
here, the reader is referred to that site:
http://www.hxa7241.org/minilight/minilight.html

Realistic Ray Tracing by Peter Shirley
Almost 100% of smallpt is derived from this book.
http://www.amazon.com/Realistic-Ray-Tracing-Peter-Shirley/dp/1568811101

Henrik Wann Jensen's Cornell box images
The inpiration of the output generated by smallpt.
http://graphics.ucsd.edu/~henrik/images/cbox.html

100 lines C++ sphereflake raytracer, by Thierry Berger-Perrin
Ray sphere intersection code stolen from here. (No full GI.)
http://ompf.org/ray/sphereflake/

sf4k, also by Thierry Berger-Perrin
Idea for 4K-ness. (No full GI.)
http://ompf.org/stuff/sf4k/

C++ vs OCaml: Ray tracer comparison, by Jon D. Harrop
105 line C++ ray tracer. (No full GI.)
http://www.ffconsultancy.com/languages/ray_tracer/comparison.html

Introduction to Linux as 4 KB Platform
Some information regarding shrinking binaries to 4KB on Linux .
http://in4k.untergrund.net/index.php?title=Linux

