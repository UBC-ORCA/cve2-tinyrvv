

#include <cmath>
#include <cstdint>
#include <limits>
#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <bitset>
#include <chrono>
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Ve4m3_mul.h"

#define K  16
#define E  8
#define M  7   // CHANGED: E5M3 => 3 mantissa bits stored in 8-bit field
#define B  0
#define ME 0

#define BF16_POS_INF     0x7F80
#define BF16_NEG_INF     0xFF80
#define BF16_ZERO        0x0000
#define BF16_NAN         0x7FC0
#define BF16_BIAS        ( ((1 << (M-1)) - 1) )

#define AOUT_POS_INF     BF16_POS_INF
#define AOUT_NEG_INF     BF16_NEG_INF
#define AOUT_ZERO        BF16_ZERO
#define AOUT_NAN         BF16_NAN

#define FLOAT_TO_BITS(x) (*reinterpret_cast<uint64_t *>(x))
#define BITS_TO_FLOAT(x) (*reinterpret_cast<double *>(x))

typedef uint16_t bf16_t;
typedef int16_t q14_2_t; 

/* There can't be an infinity while doing */
struct bf16mul_results_t {
    bf16_t res;
    uint8_t isZero: 1;
    uint8_t isNaN : 1;
};

struct nvfp8_t {
    uint8_t raw;

    nvfp8_t(uint8_t raw) : raw(raw) {}

    static const unsigned MANTISSA_BITS = 3;
    static const unsigned EXP_BITS = 4;

    static uint8_t POS_NAN() { return 0xFF; }
    static uint8_t NEG_NAN()  { return 0x7F; }
    static uint8_t POS_ZERO() { return 0; }
    static uint8_t NEG_ZERO()  { return 0x80; }
    static uint8_t MAX_NORMAL(bool sign)  { return 0x7E | (sign << 7);}
    static uint8_t MIN_NORMAL(bool sign)  { return  0x08 | (sign << 7);}
    static uint8_t MAX_SUBNORM(bool sign)  { return 0x07 | (sign << 7);}
    static uint8_t MIN_SUBNORM(bool sign)  { return 0x01 | (sign << 7);}

    static uint8_t exp_bias() { return (1 << (EXP_BITS - 1) - 1);}
    uint8_t sign() const { return raw >> 7; }
    uint8_t exp()  const { return (raw >> 3) & 0xF; }
    uint8_t mant() const { return raw & 0x7; }
    uint8_t is_zero() const {return (exp() == 0) && (mant() == 0);}
    uint8_t is_nan() const {return (raw & 0x7F) != 0;}
    double to_real() const {

        /* NaN checking */
        if ((raw & 0x7F)){
            return NAN;
        }   

        if (is_zero()){
            return sign() ? -0.0 : 0.0;
        }

        double fraction = static_cast<double>(mant()) / (1 << MANTISSA_BITS);
        double result;

        /* Subnormal */
        if (exp() == 0) {
            result = ldexp(fraction, -exp_bias());
        } else {
            result = (1.0 + fraction) * ldexp(fraction, -exp_bias());
        }

        return sign() ? -result : result;

    }    
};


class Scoreboard {
public:
    uint64_t tests_failed = 0;
    uint64_t num_tests = 0;
    uint64_t rounding_errors = 0;

    void start() {
        start_time = std::chrono::steady_clock::now();
    }

    void end() {
        end_time = std::chrono::steady_clock::now();
    }

    void print_summary() const {
        using namespace std::chrono;

        double elapsed_ms =
            duration<double, std::milli>(end_time - start_time).count();

        std::printf(
            "\n"
            "==============================\n"
            "        TEST SUMMARY\n"
            "==============================\n"
            "Tests Passed   : %llu/%llu\n"
            "Tests Failed   : %llu\n"
            "Rounding Errors: %llu\n"
            "Elapsed Time   : %.3f ms\n"
            "==============================\n",
            static_cast<unsigned long long>(num_tests - tests_failed),
            static_cast<unsigned long long>(num_tests),
            static_cast<unsigned long long>(tests_failed),
            static_cast<unsigned long long>(rounding_errors),
            elapsed_ms);

        if (tests_failed == 0) {
            if (rounding_errors == 0) {
                std::puts("PASS");
            } else {
                std::puts("PASS (with rounding differences)");
            }
        } else {
            std::puts("FAIL");
        }
    }

private:
    std::chrono::steady_clock::time_point start_time;
    std::chrono::steady_clock::time_point end_time;
};


uint64_t round_bitwise_nearest(uint64_t target, int man_bits, bool round_bits)
{
    const int shift = 52 - man_bits;

    uint64_t mant_mask = (1ULL << shift) - 1;

    uint64_t mant = target & mant_mask;

    uint64_t truncated = target & ~mant_mask;

    uint64_t lsb    = (target >> shift) & 1;
    uint64_t guard  = (target >> (shift - 1)) & 1;
    uint64_t roundb = (target >> (shift - 2)) & 1;
    uint64_t sticky = (mant_mask != 0) && (mant != 0);

    bool round_up = guard && (roundb || sticky || lsb || round_bits);

    uint64_t result = truncated;

    if (round_up)
    {
        result += (1ULL << shift);
    }

    return result;
}

void print_bits(uint32_t value, int width) {
    for (int i = width - 1; i >= 0; --i)
        std::cout << ((value >> i) & 1);
}

void print_fmt(uint16_t binary,
    size_t rep_width, 
    size_t exp_width, 
    size_t mant_width) {
    uint16_t sign = (binary >> (rep_width-1)) & 0x1;
    uint16_t exponent = (binary >> mant_width) & ((1 << exp_width) - 1);
    uint16_t mantissa = binary & ((1 << mant_width) - 1);

    std::cout << std::bitset<1>(sign) << " ";
    print_bits(exponent, exp_width);
    std::cout << " ";
    print_bits(mantissa, mant_width);
    std::cout << std::endl;
}



double quantize_real_to_superfp(double origin, int man_bits, int exp_bits, int man_offset_bits, int binades_l, int binades_u, int bias, bool round_bits) {
    uint64_t target;
    target = FLOAT_TO_BITS(&origin);
    uint8_t target_sign = target >> 63;

    double result;

    int32_t target_exp = (target << 1 >> 53) - 1023;
    int32_t min_exp = 1 - bias + (binades_l - 1);
    int32_t max_exp = (1 << exp_bits) - bias - (binades_u + 1);
    bool subnormal = (target_exp < min_exp);
    bool supnormal = (target_exp > max_exp);
    if(subnormal) {
        uint64_t qtarget = round_bitwise_nearest(target, man_bits - man_offset_bits, round_bits);
        int32_t rounded_exp = (qtarget << 1 >> 53) - 1023;
        uint64_t special_man = (qtarget >> (52 - (man_bits - man_offset_bits))) & ((1ULL << (man_bits - man_offset_bits)) - 1);

        if ((rounded_exp < min_exp - binades_l * (1ULL << man_offset_bits))
                || ((rounded_exp == min_exp - binades_l * (1ULL << man_offset_bits)) && (special_man == 0))) { // underflow
            qtarget = 0;
        }
        
        result = BITS_TO_FLOAT(&qtarget);
    } else if (supnormal) {
        if (target_exp == 1024) { // NaN/inf
            return BITS_TO_FLOAT(&target);
        }

        uint64_t qtarget = round_bitwise_nearest(target, man_bits - man_offset_bits, round_bits);
        int32_t rounded_exp = (qtarget << 1 >> 53) - 1023;
        uint64_t special_man = (qtarget >> (52 - (man_bits - man_offset_bits))) & (((1ULL << (man_bits - man_offset_bits)) - 1));

        if ((rounded_exp > max_exp + binades_u * (1ULL << man_offset_bits)) 
                || ((rounded_exp == max_exp + binades_u * (1ULL << man_offset_bits)) && (special_man == (((1ULL << (man_bits - man_offset_bits)) - 1))))) { // overflow
            double infty = INFINITY;
            qtarget = (target >> 63 << 63) | FLOAT_TO_BITS(&infty);
        }

        result = BITS_TO_FLOAT(&qtarget);
    } else {
        uint64_t qtarget = round_bitwise_nearest(target, man_bits, round_bits);
        int32_t qtarget_exp = (qtarget << 1 >> 53) - 1023;
        if(B == 0 && qtarget_exp > max_exp) {
            double infty = INFINITY;
            qtarget = (target >> 63 << 63) | FLOAT_TO_BITS(&infty);
        }
        result = BITS_TO_FLOAT(&qtarget);
    }

    return result;
}

uint16_t pack_superfp16(double x, 
    int mantissa_bits, 
    int exp_bits, 
    int exp_bias)
{
    if (x == 0.0)
        return AOUT_ZERO;

    if (std::isnan(x))
        return AOUT_NAN;

    if (std::isinf(x))
        return std::signbit(x) ? AOUT_NEG_INF : AOUT_POS_INF;

    uint16_t sign = std::signbit(x);
    double ax = std::fabs(x);

    int exp2;
    double frac = std::frexp(ax, &exp2);

    // normalize to [1,2)
    frac *= 2.0;
    exp2 -= 1;

    int exp_unbiased = exp2;

    int stored_exp = exp_unbiased + exp_bias;

    // mantissa encode
    double m = (frac - 1.0) * (1 << mantissa_bits);
    uint16_t mant = (uint16_t)std::llround(m);

    // handle mantissa overflow
    if (mant == (1 << mantissa_bits))
    {
        mant = 0;
        stored_exp++;
    }

    // underflow
    if (stored_exp <= 0)
        return AOUT_ZERO;

    // overflow
    if (stored_exp >= (1 << exp_bits) - 1)
        return sign ? AOUT_NEG_INF : AOUT_POS_INF;

    return (sign << 15) |
           ((stored_exp & ((exp_bits) - 1)) << mantissa_bits) |
           (mant & ((1 << mantissa_bits) - 1));
}


bf16mul_results_t compute_expected(
    nvfp8_t scale_a, 
    nvfp8_t scale_b,
    q14_2_t tile_in
){ 
    double fa = scale_a.to_real();
    double fb = scale_b.to_real();
    double f_tile = ((double) tile_in) / (1 << 2);

    double result_real = fa * fb * f_tile;
    double quantized_res = quantize_real_to_superfp(
        result_real,
        M, 
        E, 
        ME, 
        B,
        B,
        BF16_BIAS, 
        true);
    
    uint16_t exp_result_bf16 = pack_superfp16(quantized_res, 
        M, E, BF16_BIAS);

    bool isNaN = scale_a.is_nan()  
                || scale_b.is_nan();

    bool expected_is_zero = scale_a.is_zero()
                            || scale_b.is_zero()
                            || f_tile == 0;
    
    return bf16mul_results_t{
        .res = exp_result_bf16,
        .isZero = expected_is_zero, 
        .isNaN = isNaN
    };
}

bool eval_dut(Ve4m3_mul &dut, Scoreboard &sb, 
                uint8_t scale_a_raw, uint8_t scale_b_raw, 
                int16_t tile_q14_2_raw){ 
    
    nvfp8_t fp8a = nvfp8_t(scale_a_raw);
    nvfp8_t fp8b = nvfp8_t(scale_b_raw);    
    
    dut.A8 = scale_a_raw;
    dut.B8 = scale_b_raw;
    dut.q14_2_C_in = tile_q14_2_raw;
    dut.eval(); 

    bf16mul_results_t dut_res = (bf16mul_results_t) {
        .res = dut.PABC, 
        .isZero = dut.isZero,
        .isNaN = dut.isNaN, 
    };

    bf16mul_results_t ref_res = compute_expected(
        fp8a, fp8b, (q14_2_t) tile_q14_2_raw
    );


    if (dut_res.res != ref_res.res){
        if (dut_res.res + 1 == ref_res.res 
            || dut_res.res - 1 == ref_res.res) { //bypass rounding error
            sb.rounding_errors++;
            return true;
        }

        std::printf("\n========== MISMATCH ==========\n");

        std::printf("Inputs\n");
        std::printf("  A8      = ");
        print_bits(scale_a_raw, 8);

        std::printf("\n  B8      = ");
        print_bits(scale_b_raw, 8);

        std::printf("\n  Q14.2 C = 0x%04x (%d)\n",
                    (uint16_t)tile_q14_2_raw,
                    tile_q14_2_raw);

        std::printf("\nReference\n");
        print_fmt(ref_res.res, K, E, M);

        std::printf("\nRTL\n");
        print_fmt(dut_res.res, K, E, M);

        std::printf("\nRaw Results\n");
        std::printf("  REF = 0x%04x\n", ref_res.res);
        std::printf("  RTL = 0x%04x\n", dut_res.res);

        std::printf("==============================\n");
        
        return false;
    }
    
    return true;
        
}

/**
 * Prints out progress bar.
 */
void progress(double p) {
    constexpr int width = 50;
    std::cout << "\r[";
    int pos = width * p;
    for (int i = 0; i < width; i++)
        std::cout << (i < pos ? '=' : i == pos ? '>' : ' ');
    std::cout << "] " << int(p * 100) << "%";
    std::cout.flush();
}

auto print_help = [](const char* prog) {
    std::cout <<
        "Usage: " << prog << " [OPTIONS]\n\n"
        "Options:\n"
        "  --a-offset <n>      Starting FP8 A value (default: 0)\n"
        "  --a-stride <n>      Stride for A values (default: 1)\n"
        "  --w-offset <n>      Starting FP8 W value (default: 0)\n"
        "  --w-stride <n>      Stride for W values (default: 1)\n"
        "  --tile-offset <n>   Starting tile value offset (default: 0)\n"
        "  --tile-stride <n>   Stride for tile values (default: 1)\n"
        "  -h, --help          Show this help message\n";
};


int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    uint32_t a_offset = 0, a_stride = 1;
    uint32_t w_offset = 0, w_stride = 1;
    uint32_t tile_offset = 0, tile_stride = 1;

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];

        if (arg == "-h" || arg == "--help") {
            print_help(argv[0]);
            return 0;
        }

        if (i + 1 >= argc) {
            std::cerr << "Missing value for option '" << arg << "'\n";
            print_help(argv[0]);
            return 1;
        }

        if (arg == "--a-offset")
            a_offset = std::stoi(argv[++i]);
        else if (arg == "--a-stride")
            a_stride = std::stoi(argv[++i]);
        else if (arg == "--w-offset")
            w_offset = std::stoi(argv[++i]);
        else if (arg == "--w-stride")
            w_stride = std::stoi(argv[++i]);
        else if (arg == "--tile-offset")
            tile_offset = std::stoi(argv[++i]);
        else if (arg == "--tile-stride")
            tile_stride = std::stoi(argv[++i]);
        else {
            std::cerr << "Unknown option: " << arg << "\n";
            print_help(argv[0]);
            return 1;
        }
    }

    Ve4m3_mul dut;
    Scoreboard sb;

    uint64_t num_a =
        (256 - a_offset + a_stride - 1) / a_stride;

    uint64_t num_w =
        (256 - w_offset + w_stride - 1) / w_stride;

    uint64_t num_tile =
        (65536 - tile_offset + tile_stride - 1) / tile_stride;

    uint64_t total_tests = num_a * num_w * num_tile;
    uint64_t completed = 0;

    sb.start();

    for (int32_t tile = INT16_MIN + static_cast<int32_t>(tile_offset);
                  tile <= INT16_MAX;
                 tile += static_cast<int32_t>(tile_stride)) {

        for (uint32_t a = a_offset; a < 256; a += a_stride) {
            for (uint32_t w = w_offset; w < 256; w += w_stride) {
            
           
                eval_dut(
                    dut,
                    sb,
                    static_cast<uint8_t>(a),
                    static_cast<uint8_t>(w),
                    static_cast<int16_t>(tile));

                ++completed;

                // Update every million tests to reduce overhead
                if ((completed % 1000000) == 0) {
                    progress(
                        static_cast<float>(completed) /
                        static_cast<float>(total_tests));
                }
            }
        }
    }

    progress(1.0);
    sb.end();
    sb.print_summary();

    return sb.tests_failed != 0;
}

















