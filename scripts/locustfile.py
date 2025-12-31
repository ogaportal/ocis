#!/usr/bin/env python3
"""
Locust load testing script for ownCloud OCIS
Tests concurrent user connections and basic operations
"""
import os
from locust import HttpUser, task, between, events
from locust.exception import StopUser
import random


class OCISUser(HttpUser):
    """Simulates a user accessing ownCloud OCIS"""
    
    # Wait between 1 and 3 seconds between tasks
    wait_time = between(1, 3)
    
    def on_start(self):
        """Called when a user starts - attempt to access the homepage"""
        # SSL verification is enabled by default
        # Set to False only if testing against self-signed certificates
        self.client.verify = True
        
    @task(3)
    def access_homepage(self):
        """Access the OCIS homepage - highest weight"""
        with self.client.get("/", catch_response=True, name="Homepage") as response:
            if response.status_code == 200:
                response.success()
            elif response.status_code in [301, 302, 307, 308]:
                # Redirects are acceptable
                response.success()
            else:
                response.failure(f"Got unexpected status code: {response.status_code}")
    
    @task(2)
    def access_login_page(self):
        """Access the login page"""
        with self.client.get("/login", catch_response=True, name="Login Page") as response:
            if response.status_code in [200, 301, 302, 307, 308]:
                response.success()
            else:
                response.failure(f"Login page returned: {response.status_code}")
    
    @task(1)
    def health_check(self):
        """Check application health/readiness"""
        endpoints = ["/", "/health", "/status", "/app/"]
        endpoint = random.choice(endpoints)
        
        with self.client.get(endpoint, catch_response=True, name="Health Check") as response:
            if response.status_code in [200, 301, 302, 307, 308, 404]:
                # Even 404 means the app is responding
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Called when the test starts"""
    print("=" * 60)
    print("Starting OCIS Load Test")
    print(f"Target: {environment.host}")
    print("=" * 60)


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Called when the test stops - print summary"""
    print("\n" + "=" * 60)
    print("Load Test Summary")
    print("=" * 60)
    
    stats = environment.stats
    
    print(f"\nTotal Requests: {stats.total.num_requests}")
    print(f"Failed Requests: {stats.total.num_failures}")
    print(f"Success Rate: {((stats.total.num_requests - stats.total.num_failures) / max(stats.total.num_requests, 1)) * 100:.2f}%")
    print(f"Average Response Time: {stats.total.avg_response_time:.2f}ms")
    print(f"Max Response Time: {stats.total.max_response_time:.2f}ms")
    print(f"Requests/sec: {stats.total.total_rps:.2f}")
    
    # Determine if test passed based on criteria
    failure_rate = (stats.total.num_failures / max(stats.total.num_requests, 1)) * 100
    avg_response_time = stats.total.avg_response_time
    
    print("\n" + "=" * 60)
    print("Test Criteria Validation")
    print("=" * 60)
    
    passed = True
    
    # Check failure rate (should be < 5%)
    if failure_rate > 5.0:
        print(f"❌ FAILED: Failure rate {failure_rate:.2f}% exceeds 5% threshold")
        passed = False
    else:
        print(f"✅ PASSED: Failure rate {failure_rate:.2f}% is acceptable")
    
    # Check average response time (should be < 3000ms)
    if avg_response_time > 3000:
        print(f"❌ FAILED: Average response time {avg_response_time:.2f}ms exceeds 3000ms threshold")
        passed = False
    else:
        print(f"✅ PASSED: Average response time {avg_response_time:.2f}ms is acceptable")
    
    # Check if any requests were made
    if stats.total.num_requests == 0:
        print("❌ FAILED: No requests were made")
        passed = False
    else:
        print(f"✅ PASSED: {stats.total.num_requests} requests completed")
    
    print("=" * 60)
    
    if not passed:
        print("\n❌ Load test FAILED - Performance criteria not met")
        # Exit with error code
        environment.process_exit_code = 1
    else:
        print("\n✅ Load test PASSED - All criteria met")
        environment.process_exit_code = 0
