#include <iostream>
#include <limits>
#include <numeric>
#include <cuda.h>
#include <curand_kernel.h>
#include <cuda_runtime.h>
#include <thrust/device_vector.h>
#include <thrust/host_vector.h>

const std::size_t TOTAL_POINTS = 1e8;
const std::size_t THREADS_NUM = 32;
const std::size_t BLOCKS_NUM = 640;
const std::size_t THREAD_ITERATIONS = TOTAL_POINTS / THREADS_NUM / BLOCKS_NUM;

__global__ void monteCarlo_cuda(std::size_t* totals)
{
	__shared__ std::size_t counter[THREADS_NUM];

	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	counter[threadIdx.x] = 0;

	curandState_t rng;
	curand_init(clock64(), tid, 0, &rng);

	for (int i = 0; i < THREAD_ITERATIONS; i++)
	{
		float x = curand_uniform(&rng);
		float y = curand_uniform(&rng);
		counter[threadIdx.x] += 1 - int(x * x + y * y);
	}

	__syncthreads();

	if (threadIdx.x == 0)
	{
		totals[blockIdx.x] = 0;
		for (int i = 0; i < THREADS_NUM; i++)
		{
			totals[blockIdx.x] += counter[i];
		}
	}
}

int main()
{
	std::cout << BLOCKS_NUM << "x" << THREADS_NUM << "x" << THREAD_ITERATIONS << " ~ " <<
		THREADS_NUM * BLOCKS_NUM * THREAD_ITERATIONS << std::endl;

	thrust::host_vector<std::size_t> blocksCount(BLOCKS_NUM);
	thrust::device_vector<std::size_t> blocksCount_dev(BLOCKS_NUM);

	monteCarlo_cuda << <BLOCKS_NUM, THREADS_NUM >> > (blocksCount_dev.data().get());
	thrust::copy(blocksCount_dev.begin(), blocksCount_dev.end(), blocksCount.begin());

	const auto total = std::accumulate(blocksCount.cbegin(), blocksCount.cend(), std::size_t{});
	const auto result = 4.0 * static_cast<double>(total) / static_cast<double>(THREADS_NUM * BLOCKS_NUM * THREAD_ITERATIONS);

	std::cout.precision(std::numeric_limits<double>::max_digits10);
	std::cout << "PI ~= " << result << std::endl;
	std::cout << "Estimated with total points: " << THREADS_NUM * BLOCKS_NUM * THREAD_ITERATIONS << std::endl;

	return EXIT_SUCCESS;
}
