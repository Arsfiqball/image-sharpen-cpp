#include <vector>
#include <iostream>
#include "bitmap.h"

using namespace std;

/*
 * NOTE!
 *
 * This only works with 24-bit based uncompressed Bitmap format.
 * Use this tool below to convert your image into compatible format.
 * https://online-converting.com/image/convert2bmp/
 * also, don't forget to choose "Color" option to "24 Bit (True Color)."
 *
 * The algorithm is based on this tutorial (with few changes)
 * https://lodev.org/cgtutor/filtering.html#Sharpen
 *
 */

#define filterWidth 5
#define filterHeight 5
#define factor 0.125
#define bias 0.0

int filter[filterHeight * filterWidth] =
{
  -1, -1, -1, -1, -1,
  -1,  2,  2,  2, -1,
  -1,  2,  8,  2, -1,
  -1,  2,  2,  2, -1,
  -1, -1, -1, -1, -1,
};

__global__ void kRunFilter (int h, int w, int* filter, int* red, int* green, int* blue, int* outRed, int* outGreen, int* outBlue) {
  int x = blockIdx.x * blockDim.x + threadIdx.x;
  int y = blockIdx.y * blockDim.y + threadIdx.y;

  double newRed = 0.0;
  double newGreen = 0.0;
  double newBlue = 0.0;

  if (y < h && x < w) {
    for (int filterY = 0; filterY < filterHeight; filterY++) {
      for (int filterX = 0; filterX < filterWidth; filterX++) {
        int imageX = (x - int(filterWidth / 2) + filterX + w) % w;
        int imageY = (y - int(filterHeight / 2) + filterY + h) % h;
        newRed += red[imageY * w + imageX] * filter[filterY * filterWidth + filterX];
        newGreen += green[imageY * w + imageX] * filter[filterY * filterWidth + filterX];
        newBlue += blue[imageY * w + imageX] * filter[filterY * filterWidth + filterX];
      }
    }

    outRed[y * w + x] = min(max(int(factor * newRed + bias), 0), 255);
    outGreen[y * w + x] =  min(max(int(factor * newGreen + bias), 0), 255);
    outBlue[y * w + x] =  min(max(int(factor * newBlue + bias), 0), 255);
  }
}

int main () {
  Bitmap image;
  vector <vector <Pixel> > bmp;

  image.open("image_source.bmp");

  bool validBmp = image.isImage();

  cout << "start" << endl;

  if (validBmp == true) {
    bmp = image.toPixelMatrix();
    int h = bmp.size();
    int w = bmp[0].size();

    size_t matrixImageSize = h * w * sizeof(int);
    size_t matrixFilterSize = filterWidth * filterHeight * sizeof(int);

    int *h_red = (int*)malloc(matrixImageSize);
    int *h_green = (int*)malloc(matrixImageSize);
    int *h_blue = (int*)malloc(matrixImageSize);

    cout << "creating rgb" << endl;

    for (int i = 0; i < h; i++) {
      for (int j = 0; j < w; j++) {
        *(h_red + i * w + j) = (int) bmp[i][j].red;
        *(h_green + i * w + j) = (int) bmp[i][j].green;
        *(h_blue + i * w + j) = (int) bmp[i][j].blue;
      }
    }

    cout << "copying memories" << endl;

    int *d_red;
    int *d_green;
    int *d_blue;
    int *d_outRed;
    int *d_outGreen;
    int *d_outBlue;
    int *d_filter;

    cudaMalloc((void**)&d_red, matrixImageSize);
    cudaMalloc((void**)&d_green, matrixImageSize);
    cudaMalloc((void**)&d_blue, matrixImageSize);
    cudaMalloc((void**)&d_outRed, matrixImageSize);
    cudaMalloc((void**)&d_outGreen, matrixImageSize);
    cudaMalloc((void**)&d_outBlue, matrixImageSize);
    cudaMalloc((void**)&d_filter, matrixFilterSize);

    cudaMemcpy(d_red, h_red, matrixImageSize, cudaMemcpyHostToDevice);
    cudaMemcpy(d_green, h_green, matrixImageSize, cudaMemcpyHostToDevice);
    cudaMemcpy(d_blue, h_blue, matrixImageSize, cudaMemcpyHostToDevice);
    cudaMemcpy(d_filter, filter, matrixFilterSize, cudaMemcpyHostToDevice);

    dim3 threadsPerBlock(32, 32);
    dim3 numBlocks((int) ceil(1024 / threadsPerBlock.x), (int) ceil(1024 / threadsPerBlock.y));

    kRunFilter <<< numBlocks, threadsPerBlock >>> (
      h,
      w,
      d_filter,
      d_red,
      d_green,
      d_blue,
      d_outRed,
      d_outGreen,
      d_outBlue
    );

    cudaDeviceSynchronize();

    cudaMemcpy(h_red, d_outRed, matrixImageSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(h_green, d_outGreen, matrixImageSize, cudaMemcpyDeviceToHost);
    cudaMemcpy(h_blue, d_outBlue, matrixImageSize, cudaMemcpyDeviceToHost);

    for (int i = 0; i < h; ++i) {
      for (int j = 0; j < w; ++j) {
        bmp[i][j].red = h_red[i * w + j];
        bmp[i][j].green = h_green[i * w + j];
        bmp[i][j].blue = h_blue[i * w + j];
      }
    }

    cudaFree(d_filter);
    cudaFree(d_red);
    cudaFree(d_green);
    cudaFree(d_blue);

    free(h_red);
    free(h_green);
    free(h_blue);

    image.fromPixelMatrix(bmp);
    image.save("output.bmp");
  }

  cout << "done" << endl;

  return 0;
}
