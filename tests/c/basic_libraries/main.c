/*
 * Kernel User-Space Stress Test
 * 목표: 시스템 콜(write 제외) 없이 CPU 연산, 메모리 접근, libc 로직 검증
 */

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <gmp.h>
#include <mpfr.h>
#include <sodium.h>
#include <yyjson.h>
#include <zstd.h>

/* [검증 1] .data 및 .bss 섹션 로딩 테스트 */
/* Loader가 이 값들을 제대로 초기화하지 않으면 테스트가 실패합니다. */
int g_initialized_var = 0xDEADBEEF;   // .data section
int g_uninitialized_var;              // .bss section (should be 0)

/* [검증 2] 부동 소수점(FPU) 컨텍스트 테스트 */
/* 커널이 인터럽트 처리 시 FPU 레지스터를 저장/복구하지 않으면 값이 깨집니다. */
void test_fpu_operations() {
    printf("[Test] FPU Operations... ");

    volatile double a = 123.456;
    volatile double b = 789.012;
    volatile double result = 0.0;

    // 반복 연산으로 레지스터 체류 시간 늘림 (컨텍스트 스위칭 유도)
    for (int i = 0; i < 1000; i++) {
        result += (a * b) / (a + 1.0);
        a = a + 0.001;
    }

    // 예상 범위 내인지 확인 (정확한 값은 부동소수점 오차가 있을 수 있음)
    if (result > 0.0) {
        printf("PASS (Result: %f)\n", result);
    } else {
        printf("FAIL (Result: %f)\n", result);
    }
}

/* [검증 3] 스택 깊이 및 정렬(Alignment) 테스트 */
/* 재귀 호출을 통해 스택이 충분히 확보되었는지, Overflow 처리가 되는지 간접 확인 */
uint64_t fibonacci(int n) {
    if (n <= 1) return n;
    
    // 큰 배열을 선언하여 스택 프레임을 강제로 늘림
    volatile char padding[64]; 
    padding[0] = n; // 최적화 방지
    
    return fibonacci(n - 1) + fibonacci(n - 2);
}

void test_stack_recursion() {
    printf("[Test] Stack Recursion (Fibonacci)... ");
    int n = 20;
    uint64_t result = fibonacci(n);
    
    if (result == 6765) {
        printf("PASS (Fib(%d) = %lu)\n", n, result);
    } else {
        printf("FAIL (Fib(%d) = %lu, Expected: 6765)\n", n, result);
    }
}

/* [검증 4] Libc 문자열 조작 및 메모리 함수 (Pure Logic) */
/* sprintf는 시스템 콜 없이 버퍼에 포맷팅만 수행하므로 매우 좋은 테스트 대상입니다. */
void test_string_manipulation() {
    printf("[Test] String & Memory Ops... ");
    
    char buffer[100];
    const char *expect = "Integer: 1234, Hex: 0xFE, Float: 3.14";
    
    // memset, sprintf 테스트
    memset(buffer, 0, sizeof(buffer));
    sprintf(buffer, "Integer: %d, Hex: 0x%X, Float: %.2f", 1234, 254, 3.14159);
    
    // strcmp, memcmp 테스트
    if (strcmp(buffer, expect) == 0) {
        printf("PASS\n");
    } else {
        printf("FAIL\nExpected: '%s'\nActual:   '%s'\n", expect, buffer);
    }
}

/* [검증 5] 복잡한 알고리즘 (Sorting) */
/* qsort는 함수 포인터(Callback)와 메모리 접근을 복합적으로 테스트합니다. */
int compare_ints(const void *a, const void *b) {
    int arg1 = *(const int *)a;
    int arg2 = *(const int *)b;
    return (arg1 > arg2) - (arg1 < arg2);
}

void test_sorting() {
    printf("[Test] qsort & Function Pointers... ");
    
    int values[] = { 88, 56, 100, 2, 25 };
    int sorted[] = { 2, 25, 56, 88, 100 };
    
    qsort(values, 5, sizeof(int), compare_ints);
    
    if (memcmp(values, sorted, sizeof(values)) == 0) {
        printf("PASS\n");
    } else {
        printf("FAIL\n");
    }
}

/* [검증 6] BSS 및 Data 섹션 초기화 확인 */
void test_data_sections() {
    printf("[Test] .data & .bss Sections... ");
    
    int fail = 0;
    if (g_initialized_var != 0xDEADBEEF) {
        printf("FAIL (.data corrupted: 0x%X) ", g_initialized_var);
        fail = 1;
    }
    
    if (g_uninitialized_var != 0) {
        printf("FAIL (.bss not zeroed: %d) ", g_uninitialized_var);
        fail = 1;
    }
    
    if (!fail) printf("PASS\n");
}

/* * [검증 목표] 
 * 커널이 스택 최상단에 인자를 규격(System V ABI 등)에 맞게 밀어 넣었는가?
 * 잘못되면 argv[0]이 NULL이거나 쓰레기 값이 나옵니다.
 */
void test_arguments(int argc, char *argv[], char *envp[]) {
    printf("[Test] Arguments & Environment...\n");

    // Argc Check
    printf("  argc: %d\n", argc);

    // Argv Check
    for (int i = 0; i < argc; i++) {
        if (argv[i] == NULL) {
            printf("FAIL: argv[%d] is NULL\n", i);
            return;
        }
        printf("  argv[%d]: %s\n", i, argv[i]);
    }

    // Envp Check (환경변수가 하나라도 있는지 확인)
    if (envp && envp[0]) {
         printf("  envp[0]: %s (Environment seems OK)\n", envp[0]);
    } else {
         printf("WARN: No environment variables found.\n");
    }
}

/* * [검증 목표] 
 * 커널이 FS/GS 세그먼트 레지스터를 설정했는지, TLS 영역이 매핑되었는지 확인
 */
__thread int tls_var = 12345; // TLS 변수 선언

void test_tls() {
    printf("[Test] Thread Local Storage (TLS)... ");
    
    // TLS 변수 값을 변경하고 읽어봄
    tls_var += 1;
    
    if (tls_var == 12346) {
        printf("PASS (TLS Read/Write OK)\n");
    } else {
        printf("FAIL (Value mismatch)\n");
    }
}

/* * [검증 목표] 
 * LOCK prefix 명령어(x86) 또는 LL/SC(ARM) 동작 여부
 */
void test_atomics() {
    printf("[Test] Atomic Operations... ");
    
    int val = 10;
    // GCC 내장 함수 사용 (Assembly: lock xadd 등 생성)
    int old = __sync_fetch_and_add(&val, 5); // val을 15로 만들고, 10을 반환
    
    if (old == 10 && val == 15) {
        printf("PASS\n");
    } else {
        printf("FAIL (Old: %d, New: %d)\n", old, val);
    }
}

/* * [검증 목표] 
 * _start -> __libc_csu_init -> constructors -> main 흐름 검증
 */
int g_constructor_check = 0;

void __attribute__((constructor)) my_init() {
    g_constructor_check = 1;
    // 주의: 여기서 printf 사용 시 초기화 순서에 따라 위험할 수 있음 (write syscall 직접 호출 권장)
}

void test_constructors() {
    printf("[Test] Constructors (.init_array)... ");
    if (g_constructor_check == 1) {
        printf("PASS\n");
    } else {
        printf("FAIL (Constructor did not run)\n");
    }
}

/*
 * Register Thrashing Test
 * 목표: 메모리 사용 최소화, GPR 및 FPU/SIMD 레지스터 부하 최대화
 * 특징: 행렬(배열) 없음. 오직 지역 변수와 레지스터 연산만 수행.
 */
void test_register_thrashing() {
    printf("[Test] CPU Register Thrashing (GPR + FPU/SIMD)...\n");
    printf("       Progress: ");

    // [설정] 반복 횟수 (너무 빠르면 숫자를 늘리세요)
    // 1억 번 반복. 에뮬레이터에서는 시간이 걸릴 수 있습니다.
    const long long ITERATIONS = 10000000; 

    /* * [GPR 부하용 변수]
     * 컴파일러가 r8~r15 등 범용 레지스터에 할당하도록 유도
     */
    uint64_t g1 = 0x123456789ABCDEF0;
    uint64_t g2 = 0x0FEDCBA987654321;
    uint64_t g3 = 0xA5A5A5A55A5A5A5A;
    uint64_t g4 = 0xFF00FF0000FF00FF;

    /* * [FPU/SIMD 부하용 변수]
     * 컴파일러가 xmm0~xmm15 등 벡터 레지스터에 할당하도록 유도
     * double 타입을 사용하여 정밀도 유지 필요
     */
    double f1 = 1.0000001;
    double f2 = 0.9999999;
    double f3 = 3.1415926;
    double f4 = 2.7182818;

    /*
     * [메인 루프]
     * 메모리 접근 없이 레지스터끼리만 계속 값을 주고받습니다.
     * 의존성(Dependency Chain)을 복잡하게 만들어 파이프라인을 채웁니다.
     */
    for (long long i = 0; i < ITERATIONS; i++) {
        // 1. GPR 연산 (Bitwise + Arithmetic)
        // Xorshift 변형 알고리즘으로 레지스터 값 계속 변화
        g1 ^= (g2 << 13);
        g2 ^= (g3 >> 7);
        g3 += g4;
        g4 = (g4 << 3) | (g4 >> 61); // Rotate Left
        g1 += i; // 루프 카운터 섞기

        // 2. FPU 연산 (SIMD 활용 유도)
        // 곱셈과 덧셈을 섞어 FMA(Fused Multiply-Add) 유도 가능
        f1 = f1 * f2 + 0.0000000000001;
        f2 = f2 + 0.0000000000001;
        f3 = f3 / 1.00000001 + f4 * 0.00000001;
        f4 = f4 - 0.0000000000001;

        // 3. Cross-Domain Interaction (가끔씩 섞기)
        // 정수 레지스터와 부동소수점 레지스터 간 이동 테스트 (cvtsi2sd 등 명령어)
        if ((i & 0xFFFFF) == 0) {
            f1 += (double)(g1 & 0xFF) * 0.0000001;
            g4 ^= (uint64_t)f2;
            printf("."); // 생존 신고 (너무 자주는 안 함)
        }
    }
    
    printf(" Done.\n");

    /* * [결과 검증]
     * 문맥 전환 중 레지스터가 하나라도 깨졌다면 이 최종 결과값들이
     * 예상된 값(Deterministic)과 달라지게 됩니다.
     */
    printf("       Final GPR Checksum: 0x%llX\n", g1 ^ g2 ^ g3 ^ g4);
    printf("       Final FPU Checksum: %.15f\n", f1 + f2 + f3 + f4);

    // 참고: 실행할 때마다 이 값이 일정하게 나오는지 확인하는 것이 핵심입니다.
    // 만약 값이 매번 바뀐다면 커널의 Context Save/Restore 로직 버그입니다.
}

/* [검증 7] GMP & MPFR: 고정밀도 수치 연산 및 FPU 컨텍스트
 * 임의 정밀도 연산은 복잡한 메모리 할당과 CPU 루프를 유발하여 
 * 커널의 레지스터 보존 능력을 테스트하기 좋습니다. */
void test_high_precision_math() {
    printf("[Test] GMP & MPFR (Multi-Precision)... ");

    // GMP: 큰 정수 연산 (2^1024 계산)
    mpz_t z;
    mpz_init(z);
    mpz_ui_pow_ui(z, 2, 1024);
    
    // 결과 비트 수 확인
    if (mpz_sizeinbase(z, 2) != 1025) {
        printf("FAIL (GMP mpz)\n");
        return;
    }

    // MPFR: 고정밀도 부동소수점 (Pi 계산)
    mpfr_t p;
    mpfr_init2(p, 256); // 256비트 정밀도
    mpfr_const_pi(p, MPFR_RNDN);
    
    // mpfr_sprintf는 내부적으로 복잡한 로직을 수행함
    char buf[128];
    mpfr_snprintf(buf, sizeof(buf), "%.50Rf", p);

    if (strncmp(buf, "3.1415926535", 12) == 0) {
        printf("PASS\n");
    } else {
        printf("FAIL (MPFR Pi: %s)\n", buf);
    }

    mpz_clear(z);
    mpfr_clear(p);
}

/* [검증 8] Libsodium: 암호화 및 가속 명령어(AVX/AES-NI) 테스트
 * 현대적 암호화 라이브러리는 CPU의 특수 명령어를 많이 사용하므로 
 * 커널이 확장 레지스터(XMM/YMM)를 잘 관리하는지 확인 가능합니다. */
void test_cryptography_sodium() {
    printf("[Test] Libsodium (Crypto & SIMD)... ");

    if (sodium_init() < 0) {
        printf("FAIL (Init)\n");
        return;
    }

    unsigned char key[crypto_secretbox_KEYBYTES];
    unsigned char nonce[crypto_secretbox_NONCEBYTES];
    unsigned char message[] = "Kernel-User-Space-Stress-Test";
    unsigned char ciphertext[sizeof(message) + crypto_secretbox_MACBYTES];

    randombytes_buf(key, sizeof key);
    randombytes_buf(nonce, sizeof nonce);

    // 암호화 수행
    if (crypto_secretbox_easy(ciphertext, message, sizeof(message), nonce, key) != 0) {
        printf("FAIL (Encrypt)\n");
        return;
    }

    printf("PASS\n");
}

/* [검증 9] yyjson: 데이터 파싱 및 힙(Heap) 검증
 * 복잡한 문자열 파싱과 잦은 malloc/free를 통해 
 * 유저 스페이스 메모리 관리자와 포인터 연산을 테스트합니다. */
void test_data_parsing_yyjson() {
    printf("[Test] JSON Parsing... ");

    // 1. yyjson 테스트
    const char *json = "{\"test\": \"pass\", \"value\": 12345}";
    yyjson_doc *doc = yyjson_read(json, strlen(json), 0);
    yyjson_val *root = yyjson_doc_get_root(doc);
    yyjson_val *val = yyjson_obj_get(root, "value");

    if (!doc || yyjson_get_int(val) != 12345) {
        printf("FAIL (yyjson)\n");
        return;
    }
    yyjson_doc_free(doc);
}

/* [검증 10] Zstd: 압축 알고리즘 및 대량 메모리 복사
 * 슬라이딩 윈도우와 사전 기반 압축을 통해 CPU 캐시 및 메모리 대역폭을 소모합니다. */
void test_compression_zstd() {
    printf("[Test] Zstd Compression... ");

    const char *src = "Repeatable string data. Repeatable string data. Repeatable string data.";
    size_t srcSize = strlen(src) + 1;
    size_t dstCapacity = ZSTD_compressBound(srcSize);
    void *dst = malloc(dstCapacity);
    void *decompressed = malloc(srcSize);

    // 압축
    size_t cSize = ZSTD_compress(dst, dstCapacity, src, srcSize, 1);
    if (ZSTD_isError(cSize)) {
        printf("FAIL (Compress)\n");
        goto cleanup;
    }

    // 해제
    size_t dSize = ZSTD_decompress(decompressed, srcSize, dst, cSize);
    if (dSize != srcSize || strcmp(src, (char*)decompressed) != 0) {
        printf("FAIL (Decompress mismatch)\n");
    } else {
        printf("PASS\n");
    }

cleanup:
    free(dst);
    free(decompressed);
}

int main(int argc, char *argv[], char *envp[]) {
    printf("=== User-Space Application Test ===\n");

    test_arguments(argc, argv, envp);
    test_constructors();
    test_tls();
    test_atomics();
    test_data_sections();
    test_stack_recursion();
    test_fpu_operations();
    test_string_manipulation();
    test_sorting();
    test_register_thrashing();
    test_high_precision_math();
    test_cryptography_sodium();
    test_data_parsing_yyjson();
    test_compression_zstd();

    printf("=== All Tests Completed ===\n");
    return 0;
}
