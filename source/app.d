import std.stdio, std.complex, std.math, std.concurrency, std.parallelism;
import derelict.freeimage.freeimage;

auto immutable maxIterations = 1000;
auto immutable stepWidth = 0.01;

auto immutable realPartitions = 1;
auto immutable imaginaryPartitions = 1;
			
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
	Tid[] tids;

	DerelictFI.load();
	FreeImage_Initialise();
		
	foreach(realPartition; 0..realPartitions) {
		foreach(imaginaryPartition; 0..imaginaryPartitions) {
			writeln("spawn");
			tids ~= spawnLinked(
				&iterationThread, 
				thisTid,
				minReal + (realPartition * realPartitionWidth), 
				minImaginary + (imaginaryPartition * imaginaryPartitionWidth),
				realPartition * realsPerThread,
				imaginaryPartition * imaginariesPerThread
			);
		}
	}
	
	auto realDimension = realsPerThread * realPartitions;
	auto imaginaryDimension = imaginariesPerThread * imaginaryPartitions;
	
	auto image = FreeImage_Allocate(realDimension, imaginaryDimension, 24);
	
	auto white = RGBQUAD(255, 255, 255, 255);
	auto black = RGBQUAD(0, 0, 0, 255);
	
	writeln("waiting");
	foreach(tid; tids) {
		receive(
			(LinkTerminated exc) {
                writeln("The owner has terminated; exiting.");
            }
        );
		
		auto message = receiveOnly!(int, int, int[imaginariesPerThread][realsPerThread])();
		writeln("received");
		
		auto realStartIndex = message[0];
		auto imaginaryStartIndex = message[1];
		auto results = message[2];
		
		auto i = 0;
		foreach(line; results) {
			auto j = 0;
			foreach(num; line) {
				FreeImage_SetPixelColor(image, realStartIndex + i, imaginaryStartIndex + j, &(num >= maxIterations ? white : black));
				j++;
			}
			i++;
		}
	}
	
	FreeImage_Save(FIF_PNG, image, "mandelbrot.png", 0);
	FreeImage_DeInitialise();
}

void iterationThread(Tid ownerTid, double minReal, double minImaginary, int realStartIndex, int imaginaryStartIndex) {
	int[imaginariesPerThread][realsPerThread] results;
		
	foreach(realIndex; 0..realsPerThread) {
		foreach(imaginaryIndex; 0..imaginariesPerThread) {
			auto samplePoint = complex(minReal + realIndex * stepWidth, minImaginary + imaginaryIndex * stepWidth);
			auto numIterations = iterate(samplePoint);
			
			results[realIndex][imaginaryIndex] = numIterations;
		}
	}
	
	writeln("sending");
	ownerTid.send(realStartIndex, imaginaryStartIndex, results);
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