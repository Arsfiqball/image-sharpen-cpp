Implementation of Image Sharpening algorithm in C++ &amp; CUDA [WIP].
The algorithm is based on this tutorial (with few changes)
https://lodev.org/cgtutor/filtering.html#Sharpen

> NOTE!
  This only works with **24-bit based uncompressed Bitmap** format.
  Use this tool to convert your image into compatible format:
  https://online-converting.com/image/convert2bmp/
  also, don't forget to choose **Color** option to **24 Bit (True Color)**.

I made this program as simple as possible, and didn't rely on third party library to run.
The goal is to demonstrate how image sharpening algorithm implemented in standard CPU and GPU (CUDA) computation.
The main focus is matrix calculation of the image and how to proceed it into sharpen image.
Sample image included (filename: image_source.bmp), but you can replace it with your own.

## Compile and Run
CPU:
```sh
g++ main_cpu.cpp -o main_cpu
./main_cpu
```
GPU:
work in progress

## Maintainer
[Arsfiqball](https://github.com/Arsfiqball) | iqballmags@gmail.com
