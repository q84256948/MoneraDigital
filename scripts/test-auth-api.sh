#!/bin/bash

# Test script for Registration and Login API endpoints
# This script tests the MoneraDigital authentication endpoints

set -e

# Configuration
BASE_URL="http://localhost:8081/api"
TEST_EMAIL="test_$(date +%s)@example.com"
TEST_PASSWORD="TestPassword123"
REPORT_FILE="test_report_$(date +%Y%m%d_%H%M%S).md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Initialize report
echo "# MoneraDigital Authentication API Test Report" > "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "**Test Date:** $(date)" >> "$REPORT_FILE"
echo "**Base URL:** $BASE_URL" >> "$REPORT_FILE"
echo "**Test Email:** $TEST_EMAIL" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Function to print test header
print_test_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
    echo "## $1" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Function to print test result
print_test_result() {
    local test_name=$1
    local status=$2
    local response=$3
    local expected=$4

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        echo "- **Status:** ✓ PASS" >> "$REPORT_FILE"
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        echo "- **Status:** ✗ FAIL" >> "$REPORT_FILE"
    fi

    echo "- **Test:** $test_name" >> "$REPORT_FILE"
    echo "- **Expected:** $expected" >> "$REPORT_FILE"
    echo "- **Response:** \`\`\`json" >> "$REPORT_FILE"
    echo "$response" >> "$REPORT_FILE"
    echo "\`\`\`" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Function to extract HTTP status code
get_http_status() {
    echo "$1" | head -1 | awk '{print $2}'
}

# Function to extract response body
get_response_body() {
    echo "$1" | tail -n +2
}

echo -e "${YELLOW}Starting Authentication API Tests...${NC}\n"

# ============================================================================
# TEST 1: Register with valid credentials
# ============================================================================
print_test_header "Test 1: Register with Valid Credentials"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
    print_test_result "Register with valid credentials" "PASS" "$BODY" "HTTP 201/200 with user data"
else
    print_test_result "Register with valid credentials" "FAIL" "$BODY" "HTTP 201/200"
fi

# ============================================================================
# TEST 2: Register with duplicate email
# ============================================================================
print_test_header "Test 2: Register with Duplicate Email"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "409" ] || [ "$HTTP_CODE" = "400" ]; then
    print_test_result "Register with duplicate email" "PASS" "$BODY" "HTTP 409/400 with error message"
else
    print_test_result "Register with duplicate email" "FAIL" "$BODY" "HTTP 409/400"
fi

# ============================================================================
# TEST 3: Register with invalid email format
# ============================================================================
print_test_header "Test 3: Register with Invalid Email Format"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"invalid-email\",
    \"password\": \"$TEST_PASSWORD\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "400" ]; then
    print_test_result "Register with invalid email" "PASS" "$BODY" "HTTP 400 with validation error"
else
    print_test_result "Register with invalid email" "FAIL" "$BODY" "HTTP 400"
fi

# ============================================================================
# TEST 4: Register with weak password
# ============================================================================
print_test_header "Test 4: Register with Weak Password"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"weak_$(date +%s)@example.com\",
    \"password\": \"weak\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "400" ]; then
    print_test_result "Register with weak password" "PASS" "$BODY" "HTTP 400 with validation error"
else
    print_test_result "Register with weak password" "FAIL" "$BODY" "HTTP 400"
fi

# ============================================================================
# TEST 5: Login with valid credentials
# ============================================================================
print_test_header "Test 5: Login with Valid Credentials"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"$TEST_PASSWORD\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Extract token for later use
TOKEN=$(echo "$BODY" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4 || echo "")

if [ "$HTTP_CODE" = "200" ] && [ ! -z "$TOKEN" ]; then
    print_test_result "Login with valid credentials" "PASS" "$BODY" "HTTP 200 with JWT token"
else
    print_test_result "Login with valid credentials" "FAIL" "$BODY" "HTTP 200 with JWT token"
fi

# ============================================================================
# TEST 6: Login with invalid email
# ============================================================================
print_test_header "Test 6: Login with Invalid Email"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"nonexistent@example.com\",
    \"password\": \"$TEST_PASSWORD\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "400" ]; then
    print_test_result "Login with invalid email" "PASS" "$BODY" "HTTP 401/400 with error message"
else
    print_test_result "Login with invalid email" "FAIL" "$BODY" "HTTP 401/400"
fi

# ============================================================================
# TEST 7: Login with wrong password
# ============================================================================
print_test_header "Test 7: Login with Wrong Password"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/auth/login" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$TEST_EMAIL\",
    \"password\": \"WrongPassword123\"
  }")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "400" ]; then
    print_test_result "Login with wrong password" "PASS" "$BODY" "HTTP 401/400 with error message"
else
    print_test_result "Login with wrong password" "FAIL" "$BODY" "HTTP 401/400"
fi

# ============================================================================
# TEST 8: Get user info with valid token
# ============================================================================
print_test_header "Test 8: Get User Info with Valid Token"

if [ ! -z "$TOKEN" ]; then
    RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/auth/me" \
      -H "Authorization: Bearer $TOKEN")

    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')

    if [ "$HTTP_CODE" = "200" ]; then
        print_test_result "Get user info with valid token" "PASS" "$BODY" "HTTP 200 with user data"
    else
        print_test_result "Get user info with valid token" "FAIL" "$BODY" "HTTP 200"
    fi
else
    print_test_result "Get user info with valid token" "FAIL" "No token available" "HTTP 200 with user data"
fi

# ============================================================================
# TEST 9: Get user info without token
# ============================================================================
print_test_header "Test 9: Get User Info Without Token"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/auth/me")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "400" ]; then
    print_test_result "Get user info without token" "PASS" "$BODY" "HTTP 401/400 with error message"
else
    print_test_result "Get user info without token" "FAIL" "$BODY" "HTTP 401/400"
fi

# ============================================================================
# TEST 10: Get user info with invalid token
# ============================================================================
print_test_header "Test 10: Get User Info with Invalid Token"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$BASE_URL/auth/me" \
  -H "Authorization: Bearer invalid_token_12345")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "400" ]; then
    print_test_result "Get user info with invalid token" "PASS" "$BODY" "HTTP 401/400 with error message"
else
    print_test_result "Get user info with invalid token" "FAIL" "$BODY" "HTTP 401/400"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo -e "${YELLOW}=== Test Summary ===${NC}"
echo "## Test Summary" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "| Metric | Value |" >> "$REPORT_FILE"
echo "|--------|-------|" >> "$REPORT_FILE"
echo "| Total Tests | $TOTAL_TESTS |" >> "$REPORT_FILE"
echo "| Passed | $PASSED_TESTS |" >> "$REPORT_FILE"
echo "| Failed | $FAILED_TESTS |" >> "$REPORT_FILE"
echo "| Success Rate | $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc)% |" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

echo -e "Total Tests: ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo -e "Success Rate: ${BLUE}$(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc)%${NC}"

echo ""
echo -e "${YELLOW}Test report saved to: ${BLUE}$REPORT_FILE${NC}"

# Add test environment info to report
echo "" >> "$REPORT_FILE"
echo "## Test Environment" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "- **Base URL:** $BASE_URL" >> "$REPORT_FILE"
echo "- **Test Timestamp:** $(date)" >> "$REPORT_FILE"
echo "- **Test Email:** $TEST_EMAIL" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Add recommendations
echo "## Recommendations" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
if [ $FAILED_TESTS -eq 0 ]; then
    echo "✓ All tests passed! The authentication API is working correctly." >> "$REPORT_FILE"
else
    echo "✗ Some tests failed. Please review the failures above and fix the issues." >> "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

exit $FAILED_TESTS
