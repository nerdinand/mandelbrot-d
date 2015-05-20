import std.stdio, std.complex, std.math, std.concurrency;

auto immutable maxIterations = 1000;
auto immutable stepWidth = 0.1;

auto immutable realPartitions = 2;
auto immutable imaginaryPartitions = 2;
			
auto immutable minReal = -2.5;
auto immutable maxReal = 1.0;
auto immutable minImaginary = -1.0;
auto immutable maxImaginary = 1.0;

auto immutable realPartitionWidth = (maxReal - minReal) / realPartitions;
auto immutable imaginaryPartitionWidth = (maxImaginary - minImaginary) / imaginaryPartitions;

auto immutable realsPerThread = cast(int)(realPartitionWidth/stepWidth);
auto immutable imaginariesPerThread = cast(int)(imaginaryPartitionWidth/stepWidth);

void main() {
	Tid[] tids;
	
	foreach(realPartition; 0..realPartitions) {
		foreach(imaginaryPartition; 0..imaginaryPartitions) {
			writeln("spawn");
			tids ~= spawn(
				&iterationThread, 
				thisTid,
				minReal + (realPartition * realPartitionWidth), 
				minImaginary + (imaginaryPartition * imaginaryPartitionWidth),
			);
		}
	}
	
	// writeln("waiting");
	// int[realsPerThread][imaginariesPerThread] results = receiveOnly!(int[realsPerThread][imaginariesPerThread])();
}

void iterationThread(Tid ownerTid, double minReal, double minImaginary) {
	int[realsPerThread][imaginariesPerThread] results;
	
	writeln(thisTid, " ", minReal, " ", minImaginary);
	
	foreach(realIndex; 0..realsPerThread) {
		writeln(minReal, " line ", realIndex, " start");
		foreach(imaginaryIndex; 0..imaginariesPerThread) {
			auto samplePoint = complex(minReal + realIndex * stepWidth, minImaginary + imaginaryIndex * stepWidth);
			auto numIterations = iterate(samplePoint);
			results[realIndex][imaginaryIndex] = numIterations;
		}
		writeln(minReal, " line ", realIndex, " end");
	}
	
	writeln("sending");
	ownerTid.send(thisTid, results);
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