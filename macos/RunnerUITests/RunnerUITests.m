@import XCTest;
@import patrol;
@import ObjectiveC.runtime;

// Expanded from PATROL_INTEGRATION_TEST_MACOS_RUNNER(RunnerUITests) so that the
// error from PatrolServer.start() is actually captured and logged (the macro
// passes a NULL NSError** and silently swallows bind failures).
@interface RunnerUITests : XCTestCase
@end

@implementation RunnerUITests

+ (NSArray<NSInvocation *> *)testInvocations {
  /* Start native automation server */
  PatrolServer *server = [[PatrolServer alloc] init];

  NSError *err = nil;
  BOOL started = [server startAndReturnError:&err];
  if (!started) {
    NSLog(@"patrolServer.start(): failed, err: %@", err);
  }

  NSLog(@"Create PatrolAppServiceClient");

  /* Create a client for PatrolAppService, which lets us list and run Dart tests */
  __block ObjCPatrolAppServiceClient *appServiceClient = [[ObjCPatrolAppServiceClient alloc] init];

  NSLog(@"Run the app for the first time");

  /* Run the app for the first time to gather Dart tests */
  [[[XCUIApplication alloc] init] launch];

  NSLog(@"Waiting until the app reports that it is ready");

  /* Spin the runloop waiting until the app reports that it is ready to report Dart tests */
  while (!server.appReady) {
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  }

  NSLog(@"listDartTests");

  __block NSArray<NSDictionary *> *dartTests = NULL;
  [appServiceClient
      listDartTestsWithCompletion:^(NSArray<NSDictionary *> *_Nullable tests, NSError *_Nullable err2) {
        if (err2 != NULL) {
          NSLog(@"listDartTests(): failed, err: %@", err2);
        }

        dartTests = tests;
      }];

  NSLog(@"Spin the runloop waiting");

  /* Spin the runloop waiting until the app reports the Dart tests it contains */
  while (!dartTests) {
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:5.0]];
  }

  NSLog(@"Got %lu Dart tests: %@", dartTests.count, dartTests);

  NSMutableArray<NSInvocation *> *invocations = [[NSMutableArray alloc] init];

  for (NSDictionary *dartTest in dartTests) {
    /* Step 1 - dynamically create test cases */
    NSString *dartTestName = dartTest[@"name"];
    BOOL skip = [dartTest[@"skip"] boolValue];

    IMP implementation = imp_implementationWithBlock(^(id _self) {
      [[[XCUIApplication alloc] init] launch];
      if (skip) {
        XCTSkip(@"Skip that test \"%@\"", dartTestName);
      }

      __block ObjCRunDartTestResponse *response = NULL;
      __block NSError *error;
      [appServiceClient
          runDartTestWithName:dartTestName
                   completion:^(ObjCRunDartTestResponse *_Nullable r, NSError *_Nullable err3) {
                     NSString *status;
                     if (err3 != NULL) {
                       error = err3;
                       status = @"CRASHED";
                     } else {
                       response = r;
                       status = response.passed ? @"PASSED" : @"FAILED";
                     }
                     NSLog(@"runDartTest(\"%@\"): call finished, test result: %@", dartTestName, status);
                   }];

      /* Wait until Dart test finishes (either fails or passes) or crashes */
      while (!response && !error) {
        [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
      }
      BOOL passed = response ? response.passed : NO;
      NSString *details = response ? response.details : @"(no details - app likely crashed)";
      XCTAssertTrue(passed, @"%@", details);
    });
    SEL selector = NSSelectorFromString(dartTestName);
    class_addMethod(self, selector, implementation, "v@:");

    /* Step 2 – create invocations to the dynamically created methods */
    NSMethodSignature *signature = [self instanceMethodSignatureForSelector:selector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;

    NSLog(@"RunnerUITests.testInvocations(): selectorName = %@, signature: %@", dartTestName, signature);

    [invocations addObject:invocation];
  }

  return invocations;
}

@end
