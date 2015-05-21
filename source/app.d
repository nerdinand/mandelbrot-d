import std.stdio, std.complex, std.math, std.concurrency, std.parallelism;
import derelict.freeimage.freeimage;

auto immutable maxIterations = 1000;
auto immutable stepWidth = 0.01;

auto immutable realPartitions = 16;
auto immutable imaginaryPartitions = 16;
			
auto immutable minReal = -2.5;
auto immutable maxReal = 1.0;
auto immutable minImaginary = -1.0;
auto immutable maxImaginary = 1.0;

auto immutable realLength = maxReal - minReal;
auto immutable imaginaryLength = maxImaginary - minImaginary;

auto immutable realPartitionWidth = realLength / realPartitions;
auto immutable imaginaryPartitionWidth = imaginaryLength / imaginaryPartitions;

auto immutable realsPerThread = cast(int)(realPartitionWidth/stepWidth);
auto immutable imaginariesPerThread = cast(int)(imaginaryPartitionWidth/stepWidth);

void main() {
	writeln("realsPerThread: ", realsPerThread);
	writeln("imaginariesPerThread: ", imaginariesPerThread);
	
	writeln("totalCPUs: ", totalCPUs);
	
	DerelictFI.load();
	FreeImage_Initialise();
	
	Task!(parallelTask, double, double)*[] tasks;
	int[] realStartIndices;
	int[] imaginaryStartIndices;
	
	foreach(realPartition; 0..realPartitions) {
		foreach(imaginaryPartition; 0..imaginaryPartitions) {
			writeln("spawn");
			
			auto newTask = task!parallelTask(minReal + (realPartition * realPartitionWidth), minImaginary + (imaginaryPartition * imaginaryPartitionWidth));
    		newTask.executeInNewThread();
    		
    		tasks ~= newTask;
    		realStartIndices ~= realPartition * realsPerThread;
    		imaginaryStartIndices ~= imaginaryPartition * imaginariesPerThread;
		}
	}
	
	auto realDimension = realsPerThread * realPartitions;
	auto imaginaryDimension = imaginariesPerThread * imaginaryPartitions;
	
	auto image = FreeImage_Allocate(realDimension, imaginaryDimension, 24);
	
	writeln("waiting");
	int taskIndex = 0;
	foreach(task; tasks) {
		auto results = task.yieldForce();
		
		auto realStartIndex = realStartIndices[taskIndex];
		auto imaginaryStartIndex = imaginaryStartIndices[taskIndex];
		
		auto i = 0;
		foreach(line; results) {
			auto j = 0;
			foreach(numIterations; line) {
				auto color = numIterationsToColor(numIterations);
				FreeImage_SetPixelColor(image, realStartIndex + i, imaginaryStartIndex + j, &color);
				j++;
			}
			i++;
		}
		
		taskIndex++;
	}
	
	FreeImage_Save(FIF_PNG, image, "mandelbrot.png", 0);
	FreeImage_DeInitialise();
}

RGBQUAD numIterationsToColor(int numIterations) {
	ubyte r = cast(ubyte) (numIterations * 0.255);
	ubyte b = cast(ubyte) (numIterations * 0.255);
	ubyte g = cast(ubyte) (numIterations * 0.255);
	return RGBQUAD(r, g, b, 255);
}

int[imaginariesPerThread][realsPerThread] parallelTask(double minReal, double minImaginary) {
	int[imaginariesPerThread][realsPerThread] results;
	
	foreach(realIndex; 0..realsPerThread) {
		foreach(imaginaryIndex; 0..imaginariesPerThread) {
			auto samplePoint = complex(minReal + realIndex * stepWidth, minImaginary + imaginaryIndex * stepWidth);
			auto numIterations = iterate(samplePoint);
			
			results[realIndex][imaginaryIndex] = numIterations;
		}
	}
	
	writeln("return");
	
	return results;
}

auto iterate(immutable Complex!double samplePoint) {
	auto numIterations = 0;
	
	auto lastIteration = Complex!double(0, 0);
	while(numIterations < maxIterations && abs(lastIteration)^^2.0 <= 4) {
		lastIteration = lastIteration^^2 + samplePoint;
		numIterations++;
	}
		
	return numIterations;
}