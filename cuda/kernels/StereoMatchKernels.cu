#include "cuda.h"
#include "StereoMatchKernels.cuh"

// TODO Subpixel Genauigkeit
__global__ void kernelStereoMatchL2R(unsigned char* dev_leftImg,
		unsigned char* dev_rightImg, float* dev_disparity, int width,
		int height, int kernelSize, int maxDisp, bool colorInput,
		bool subPixel) {

	int idx = threadIdx.x + blockIdx.x * blockDim.x;
	int imgX = idx % width;
	int imgY = idx / width;
	int imgSize = width * height;
	int halfKS = kernelSize / 2;

	bool doCalc = imgY > halfKS && imgY < height - halfKS && imgX > halfKS
			&& imgX < width - halfKS;

	int bytesPerPixel = colorInput ? 3 : 1;

	// Berechne disparitätswert für pixel idx
	if (doCalc) {
		// x,y gegeben. Berechne x2 und disparität
		int bestSAD = 65532;
		int bestDisparity = 0;
		unsigned char* pX1L = dev_leftImg
				+ (idx - halfKS - halfKS * width) * bytesPerPixel; // Zeiger auf Anfang des Kernel
		unsigned char* pX1R = dev_rightImg
				+ (idx - halfKS - halfKS * width) * bytesPerPixel;

		for (int currDisp = 0; currDisp >= -maxDisp; currDisp--) {
			if (currDisp + imgX < 0)
				break;

			int sad = 0;
			unsigned char* pL = pX1L;
			unsigned char* pR = pX1R + currDisp * bytesPerPixel;

			// Berechne SAD (y,x1,x2)
			for (int dy = -halfKS; dy <= halfKS; dy++) {
				for (int dx = -halfKS; dx <= halfKS; dx++) {
					if (colorInput)
						// Color diff
//						sad += sqrtf((*pL - *pR) * (*pL++ - *pR++)
//								  + (*pL - *pR) * (*pL++ - *pR++)
//								  + (*pL - *pR) * (*pL++ - *pR++));
						sad += abs(*pL++ - *pR++) + abs(*pL++ - *pR++)
								+ abs(*pL++ - *pR++);
					else
						sad += abs(*pL++ - *pR++);	// delta;

				}
				pL += (width - kernelSize) * bytesPerPixel;
				pR += (width - kernelSize) * bytesPerPixel;
			}

			if (sad < bestSAD) {
				bestSAD = sad;
				bestDisparity = currDisp;
			}
		}
		dev_disparity[idx] = abs(bestDisparity);
	}
	__syncthreads();

}
__global__ void kernelStereoMatchR2L(unsigned char* dev_leftImg,
		unsigned char* dev_rightImg, float* dev_disparity, int width,
		int height, int kernelSize, int maxDisp, bool colorInput,
		bool subPixel) {

	int idx = threadIdx.x + blockIdx.x * blockDim.x;
	int imgX = idx % width;
	int imgY = idx / width;
	int imgSize = width * height;
	int halfKS = kernelSize / 2;

	bool doCalc = imgY > halfKS && imgY < height - halfKS && imgX > halfKS
			&& imgX < width - halfKS;

	int bytesPerPixel = colorInput ? 3 : 1;

	// Berechne disparitätswert für pixel idx
	if (doCalc) {
		// x,y gegeben. Berechne x2 und disparität
		int bestSAD = 65532;
		int bestDisparity = 0;
		unsigned char* pX1L = dev_leftImg
				+ (idx - halfKS - halfKS * width) * bytesPerPixel;// Zeiger auf Anfang des Kernel
		unsigned char* pX1R = dev_rightImg
				+ (idx - halfKS - halfKS * width) * bytesPerPixel;

		for (int currDisp = 0; currDisp <= maxDisp; currDisp++) {
			if (currDisp + imgX >= width)
				break;

			int sad = 0;
			unsigned char* pL = pX1L + currDisp * bytesPerPixel;
			unsigned char* pR = pX1R;

			// Berechne SAD (y,x1,x2)
			for (int dy = -halfKS; dy <= halfKS; dy++) {
				for (int dx = -halfKS; dx <= halfKS; dx++) {
					if (colorInput)
						// Color diff
//						sad += sqrtf((*pL - *pR) * (*pL++ - *pR++)
//								  + (*pL - *pR) * (*pL++ - *pR++)
//								  + (*pL - *pR) * (*pL++ - *pR++));
						sad += abs(*pL++ - *pR++) + abs(*pL++ - *pR++)
								+ abs(*pL++ - *pR++);
					else
						sad += abs(*pL++ - *pR++);	// delta;

				}
				pL += (width - kernelSize) * bytesPerPixel;
				pR += (width - kernelSize) * bytesPerPixel;
			}

			if (sad < bestSAD) {
				bestSAD = sad;
				bestDisparity = currDisp;
			}
		}
		dev_disparity[idx] = abs(bestDisparity);
	}
	__syncthreads();

}
__global__ void kernelLRConsistencyCheck(float* dev_dispLeft,
		float* dev_dispRight, int width, int height, int kernelSize,
		int consistencyTreshold, bool colorInput) {
	int idx = threadIdx.x + blockIdx.x * blockDim.x;
	int imgX = idx % width;
	int imgY = idx / width;
	int imgSize = width * height;
	int halfKS = kernelSize / 2;

	bool doCalc = imgY > halfKS && imgY < height - halfKS && imgX > halfKS
			&& imgX < width - halfKS;

	if (doCalc) {
		int xR = imgX - dev_dispLeft[idx];
		if (xR < 0 || xR >= width) {
			dev_dispLeft[idx] = 0;
			dev_dispRight[idx] = 0;
		} else {
			int idxR = imgY * width + xR;
			if (abs(int(dev_dispLeft[idx] - dev_dispRight[idxR]))
					> consistencyTreshold) {
				dev_dispLeft[idx] = 0;
				dev_dispRight[idx] = 0;
			}
		}
	}
}
