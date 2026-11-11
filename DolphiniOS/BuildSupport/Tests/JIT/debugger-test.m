#import <Foundation/Foundation.h>
#import "JitManager.h"
#import "JitManager+Debugger.h"
#include <assert.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>

static int reportedFlags;
static int reportedError;
int csops(pid_t pid, unsigned int operation, void* output, size_t size) {
  assert(pid == getpid());
  assert(operation == 0);
  assert(size == sizeof(int));
  if (reportedError) return -1;
  memcpy(output, &reportedFlags, size);
  return 0;
}
#pragma clang diagnostic ignored "-Wincomplete-implementation"
@implementation JitManager
@end
int main(void) {
  @autoreleasepool {
    JitManager* manager = [JitManager new];
    reportedFlags = 0;
    assert(![manager checkIfProcessIsDebugged]);
    reportedFlags = 0x10000000;
    assert([manager checkIfProcessIsDebugged]);
    reportedError = 1;
    assert(![manager checkIfProcessIsDebugged]);
    puts("PASS: real debugger status implementation passes the complete flag buffer and handles errors");
  }
}
