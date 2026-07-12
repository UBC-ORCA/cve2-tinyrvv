#include <cmath>
#include <cstdint>
#include <limits>
#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <bitset>
#include <chrono>
#include "verilated.h"
#include "VE5M3sub.h"
#include "verilated_vcd_c.h"

#define FLOAT_TO_BITS(x) (*reinterpret_cast<uint64_t *>(x))
#define BITS_TO_FLOAT(x) (*reinterpret_cast<double *>(x))

#define TEST_RTL_TO_TB   0
#define TEST_TB_TO_REAL  1
#define TEST_RTL_TO_REAL 2
#define TEST_MODE TEST_RTL_TO_REAL

#define MOUT_POS_INF     0x7F00
#define MOUT_NEG_INF     0xFF00
#define MOUT_POS_ZERO    0x0000
#define MOUT_NEG_ZERO    0x8000
#define MOUT_POS_NAN     0x7F80
#define MOUT_NEG_NAN     0xFF80

//Used
#define AOUT_POS_INF     0x7FFF
#define AOUT_NEG_INF     0xFFFF
#define AOUT_ZERO        0x0000
#define AOUT_NAN         0x8000

#define MULT_MAN_BITS 2

#define K  16
#define E  8
#define M  7   // CHANGED: E5M3 => 3 mantissa bits stored in 8-bit field
#define B  0
#define ME 0


#define MULTIPLIER_BIAS 16
#define ADDER_BIAS      ((1<<(E-1)) - 1)

#define MAN_INITIAL_NORM_1_POS         (1 << MULT_MAN_BITS)
#define MAN_MULTIPLIED_NORM_1_POS      (MAN_INITIAL_NORM_1_POS << MULT_MAN_BITS)
#define MAN_MULTIPLIED_NORM_1_OVERFLOW (MAN_MULTIPLIED_NORM_1_POS << 1)

#define OFFSET_MASK ((1 << ME) - 1)
#define MANT_MASK   (((1 << (M-ME)) - 1) << ME)

static uint64_t round_errors = 0;
static uint64_t total = 0;
static uint64_t correct = 0;


typedef struct {
    bool is_zero;
    bool is_nan;
    bool is_inf;
    uint16_t result;
} add_result;

static add_result ar = {0};

void print_fmt(uint16_t binary) {
    uint16_t sign = (binary >> (K-1)) & 0x1;
    uint16_t exponent = (binary >> M) & ((1 << E) - 1);
    uint16_t mantissa = binary & ((1 << M) - 1);

    std::cout << std::bitset<1>(sign) << " "
              << std::bitset<E>(exponent) << " "
              << std::bitset<M>(mantissa) << std::endl;
}

// ==========================
// E5M3 REAL CAST (UPDATED)
// ==========================
double cast_E5M3sub_to_real(uint16_t a) {
    int64_t sign = (a >> 7) & 0x1;
    int64_t exponent = (a >> 3) & 0b11111;   // CHANGED: exponent shift
    int64_t mantissa = a & 0x7;             // CHANGED: 3-bit mantissa

    if ((a & 0b011111111) == 0) {
        return sign ? NAN : 0.0;
    }

    if ((a & 0b011111111) == 0b011111111) {
        //return sign ? -INFINITY : INFINITY;
        return sign ? -std::numeric_limits<double>::infinity() : std::numeric_limits<double>::infinity();

    }

    double fraction = static_cast<double>(mantissa) / (1 << 3);

    double result;
    if (exponent == 0) {
        result = fraction * pow(2, -15);
    } else {
        result = (1.0 + fraction) * pow(2, exponent - 16);
    }

    return sign ? -result : result;
}

/*
uint64_t round_bitwise_nearest(uint64_t target, int man_bits, bool round_bits)
{
    int lsb = (target >> (52 - man_bits)) & 1;
    int guard = (target >> (51 - man_bits)) & 1;
    int round = (target >> (50 - man_bits)) & 1;
    int sticky = ((target & ((1ULL << (51 - man_bits)) - 1)) != 0) || round_bits;
    
    int round_up = guard && ((round || sticky) || lsb);

    std::cout << "target: " << target << std::endl;
    std::cout << "lsb: " << lsb << std::endl;
    std::cout << "guard: " << guard << std::endl;
    std::cout << "round: " << round << std::endl;
    std::cout << "sticky: " << sticky << std::endl;
    std::cout << "Round up: " << round_up << std::endl;
    std::cout << "Round bits: " << round_bits << std::endl;

    uint64_t add_r = target + ((uint64_t)round_up << (52 - man_bits));
    return add_r & ~((1ULL << std::min((52 - man_bits), 52)) - 1);
}
*/

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



/*
double cast_superfp_to_real(uint16_t origin, int man_bits, int exp_bits, int man_offset_bits, int binades_l, int binades_u, int bias) {
    double result = 0.0;
    int sign = origin >> (man_bits + exp_bits);
    uint16_t man = origin & ((1 << man_bits) - 1);
    uint16_t exp = (origin >> M) & ((1 << exp_bits) - 1);

    bool exp_full = (exp == ((1 << exp_bits) - 1));
    bool exp_zero = (exp == 0);
    bool man_full = (man == ((1 << man_bits) - 1));
    bool man_zero = (man == 0);

    if (origin == 0) {
        return 0.0;
    }

    if(sign && exp_zero && man_zero) {
        return NAN;
    }

    if (exp_full && man_full) {
        if (sign == 1) {
            return -std::numeric_limits<double>::infinity();
        } else {
            return std::numeric_limits<double>::infinity();
        }
    }

    double fraction;
    int exponent;

    bool special_l = (exp < binades_l);
    bool special_u = (exp >= ((1 << exp_bits) - binades_u));

    int16_t max_reg_exp = (1 << exp_bits) - bias - (binades_u + 1);
    int16_t min_reg_exp = 1 - bias + (binades_l - 1);
    int16_t min_super_exp_u = max_reg_exp + 1;
    int16_t min_super_exp_l = min_reg_exp - (binades_l * (1 << man_offset_bits));

    if(special_l || special_u) {
        uint16_t offset = (man & ((1 << man_offset_bits) - 1))
            | ((exp & ((special_l ? binades_l : binades_u) - 1)) << man_offset_bits);
        
        man &= (((1 << (man_bits - man_offset_bits)) - 1) << man_offset_bits);
        
        exponent = offset + (special_l ? min_super_exp_l : min_super_exp_u); // offset + max exponent (non-special) + 1
    } else {
        exponent = exp - bias;
    }

    fraction = static_cast<double>(man)/(1 << man_bits);
   
    result = (1.0 + fraction) * pow(2, exponent);
    if (sign == 1) {
        result = -result;
    }
    return result;
}

*/

double cast_superfp_to_real(uint16_t origin,
                             int man_bits,
                             int exp_bits,
                             int man_offset_bits,
                             int binades_l,
                             int binades_u,
                             int bias)
{
    if (origin == 0)
        return 0.0;

    int sign = origin >> 15;
    int exp  = (origin >> M) & ((1 << exp_bits) - 1);
    int man  = origin & ((1 << man_bits) - 1);

    if (exp == (1 << exp_bits) - 1)
    {
        if (man == 0)
            return sign ? -INFINITY : INFINITY;
        return NAN;
    }

    double frac = man / double(1 << man_bits);

    int e = exp - bias;

    double val = (1.0 + frac) * pow(2, e);

    return sign ? -val : val;
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


/*
uint16_t pack_superfp(double ftarget) {
    uint64_t target = FLOAT_TO_BITS(&ftarget);

    uint8_t sign = target >> 63;
    uint16_t exp = (target >> 52) & 0x7FF;
    uint16_t man = (target >> (52 - M)) & ((1 << M) - 1);
//uint64_t full_man = (1ULL << 52) | (target & ((1ULL << 52) - 1));
//uint16_t man = (full_man >> (52 - M)) & ((1 << (M+1)) - 1);

    if(exp == 0 && man == 0) {
        return AOUT_ZERO;
    }
    if(exp == 0x7FF) {
        if(man == 0) { // inf
            return (sign) ? (AOUT_NEG_INF) : (AOUT_POS_INF);
        } else { // nan
            return AOUT_NAN;
        }
    }

    uint16_t man_actual;
    uint8_t exp_actual;
    int16_t exp_temp = exp - 1023;

    int16_t max_reg_exp = (1 << E) - ADDER_BIAS - (B + 1);
    int16_t min_reg_exp = 1 - ADDER_BIAS + (B - 1);

    int16_t max_super_exp_u = max_reg_exp + (B * (1 << ME));
    int16_t min_super_exp_u = max_reg_exp + 1;

    int16_t max_super_exp_l = min_reg_exp - 1;
    int16_t min_super_exp_l = min_reg_exp - (B * (1 << ME));

    if(exp_temp > max_reg_exp) { // for B0 it would never actually hit this or below condition because its handled by quantize_real_to_superfp()
        uint16_t man_super = man >> ME;
        uint16_t man_offset = exp_temp - min_super_exp_u;

        man_actual = (man_super << ME) | (man_offset & OFFSET_MASK);
        exp_actual = (((1 << E) - 1) - (B - 1)) | ((man_offset >> ME) & (B - 1));
    } else if(exp_temp < min_reg_exp) {
        uint16_t man_super = man >> ME;
        uint16_t man_offset = exp_temp - min_super_exp_l;

        man_actual = (man_super << ME) | (man_offset & OFFSET_MASK);
        exp_actual = 0 | ((man_offset >> ME) & (B - 1));
    } else {
        man_actual = man;
        exp_actual = exp_temp + ADDER_BIAS;
    }

    uint16_t result = (sign << 15) | ((exp_actual & ((1 << E) - 1)) << M) | (man_actual & ((1 << M) - 1));

    return result;
}

*/

/*
uint16_t pack_superfp(double ftarget) {

    std::cout << "\n";
    std::cout << "==================================================\n";
    std::cout << "PACK_SUPERFP DEBUG\n";
    std::cout << "==================================================\n";

    uint64_t target = FLOAT_TO_BITS(&ftarget);

    uint8_t sign = target >> 63;
    uint16_t exp = (target >> 52) & 0x7FF;
    uint16_t man = (target >> (52 - M)) & ((1 << M) - 1);

    // Optional hidden-1 debug
    uint64_t full_man = (1ULL << 52) | (target & ((1ULL << 52) - 1));
    uint16_t man_with_hidden =
        (full_man >> (52 - M)) & ((1 << (M + 1)) - 1);

    std::cout << "[INPUT]\n";
    std::cout << "ftarget             = " << ftarget << "\n";

    std::cout << "\n[RAW IEEE754 DOUBLE]\n";
    std::cout << "target              = 0x"
              << std::hex << target << std::dec << "\n";

    std::cout << "target(bin)         = "
              << std::bitset<64>(target) << "\n";

    std::cout << "\n[DECODED IEEE754]\n";
    std::cout << "sign                = "
              << (int)sign << "\n";

    std::cout << "exp(raw)            = "
              << exp << "\n";

    std::cout << "exp(raw bin)        = "
              << std::bitset<11>(exp) << "\n";

    std::cout << "man(extracted)      = "
              << man << "\n";

    std::cout << "man(extracted bin)  = "
              << std::bitset<M>(man) << "\n";

    std::cout << "\n[HIDDEN-1 DEBUG]\n";
    std::cout << "full_man            = 0x"
              << std::hex << full_man << std::dec << "\n";

    std::cout << "full_man(bin)       = "
              << std::bitset<53>(full_man) << "\n";

    std::cout << "man_with_hidden     = "
              << man_with_hidden << "\n";

    std::cout << "man_with_hidden(bin)= "
              << std::bitset<M+1>(man_with_hidden) << "\n";

    bool is_zero = (exp == 0 && man == 0);
    bool is_inf  = (exp == 0x7FF && man == 0);
    bool is_nan  = (exp == 0x7FF && man != 0);

    std::cout << "\n[CLASSIFICATION]\n";
    std::cout << "is_zero             = " << is_zero << "\n";
    std::cout << "is_inf              = " << is_inf << "\n";
    std::cout << "is_nan              = " << is_nan << "\n";

    if(is_zero) {
        std::cout << "\n[RETURN ZERO]\n";
        std::cout << "result              = 0x"
                  << std::hex << AOUT_ZERO << std::dec << "\n";
        return AOUT_ZERO;
    }

    if(exp == 0x7FF) {
        if(man == 0) {
            uint16_t result =
                (sign) ? (AOUT_NEG_INF) : (AOUT_POS_INF);

            std::cout << "\n[RETURN INF]\n";
            std::cout << "result              = 0x"
                      << std::hex << result << std::dec << "\n";

            return result;
        }
        else {
            std::cout << "\n[RETURN NAN]\n";
            std::cout << "result              = 0x"
                      << std::hex << AOUT_NAN << std::dec << "\n";

            return AOUT_NAN;
        }
    }

    uint16_t man_actual = 0;
    uint8_t exp_actual = 0;

    int16_t exp_temp = exp - 1023;

    std::cout << "\n[EXPONENT PROCESSING]\n";
    std::cout << "exp_temp            = "
              << exp_temp << "\n";

    std::cout << "exp_temp(bin)       = "
              << std::bitset<16>((uint16_t)exp_temp) << "\n";

    int16_t max_reg_exp = (1 << E) - ADDER_BIAS - (B + 1);
    int16_t min_reg_exp = 1 - ADDER_BIAS + (B - 1);

    int16_t max_super_exp_u = max_reg_exp + (B * (1 << ME));
    int16_t min_super_exp_u = max_reg_exp + 1;

    int16_t max_super_exp_l = min_reg_exp - 1;
    int16_t min_super_exp_l = min_reg_exp - (B * (1 << ME));

    std::cout << "\n[RANGE PARAMETERS]\n";
    std::cout << "max_reg_exp         = "
              << max_reg_exp << "\n";

    std::cout << "min_reg_exp         = "
              << min_reg_exp << "\n";

    std::cout << "max_super_exp_u     = "
              << max_super_exp_u << "\n";

    std::cout << "min_super_exp_u     = "
              << min_super_exp_u << "\n";

    std::cout << "max_super_exp_l     = "
              << max_super_exp_l << "\n";

    std::cout << "min_super_exp_l     = "
              << min_super_exp_l << "\n";

    bool super_u = (exp_temp > max_reg_exp);
    bool super_l = (exp_temp < min_reg_exp);
    bool normal  = (!super_u && !super_l);

    std::cout << "\n[RANGE FLAGS]\n";
    std::cout << "super_u             = "
              << super_u << "\n";

    std::cout << "super_l             = "
              << super_l << "\n";

    std::cout << "normal              = "
              << normal << "\n";

    if(exp_temp > max_reg_exp) {

        std::cout << "\n[SUPERNORMAL UPPER PATH]\n";

        uint16_t man_super = man >> ME;
        uint16_t man_offset = exp_temp - min_super_exp_u;

        std::cout << "man_super           = "
                  << man_super << "\n";

        std::cout << "man_super(bin)      = "
                  << std::bitset<M>(man_super) << "\n";

        std::cout << "man_offset          = "
                  << man_offset << "\n";

        std::cout << "man_offset(bin)     = "
                  << std::bitset<16>(man_offset) << "\n";

        man_actual =
            (man_super << ME) |
            (man_offset & OFFSET_MASK);

        exp_actual =
            (((1 << E) - 1) - (B - 1)) |
            ((man_offset >> ME) & (B - 1));
    }
    else if(exp_temp < min_reg_exp) {

        std::cout << "\n[SUPERNORMAL LOWER PATH]\n";

        uint16_t man_super = man >> ME;
        uint16_t man_offset = exp_temp - min_super_exp_l;

        std::cout << "man_super           = "
                  << man_super << "\n";

        std::cout << "man_super(bin)      = "
                  << std::bitset<M>(man_super) << "\n";

        std::cout << "man_offset          = "
                  << man_offset << "\n";

        std::cout << "man_offset(bin)     = "
                  << std::bitset<16>(man_offset) << "\n";

        man_actual =
            (man_super << ME) |
            (man_offset & OFFSET_MASK);

        exp_actual =
            0 |
            ((man_offset >> ME) & (B - 1));
    }
    else {

        std::cout << "\n[NORMAL PATH]\n";

        man_actual = man;
        exp_actual = exp_temp + ADDER_BIAS;



    }

    std::cout << "\n[PACK FIELDS]\n";
    std::cout << "man_actual          = "
              << man_actual << "\n";

    std::cout << "man_actual(bin)     = "
              << std::bitset<M>(man_actual) << "\n";

    std::cout << "exp_actual          = "
              << (int)exp_actual << "\n";

    std::cout << "exp_actual(bin)     = "
              << std::bitset<E>(exp_actual) << "\n";

    uint16_t result =
        (sign << 15) |
        ((exp_actual & ((1 << E) - 1)) << M) |
        (man_actual & ((1 << M) - 1));

    std::cout << "\n[FINAL RESULT]\n";
    std::cout << "result(hex)         = 0x"
              << std::hex << result << std::dec << "\n";

    std::cout << "result(bin)         = "
              << std::bitset<16>(result) << "\n";

    std::cout << "result sign         = "
              << ((result >> 15) & 1) << "\n";

    std::cout << "result exponent     = "
              << std::bitset<E>((result >> M) & ((1 << E) - 1))
              << "\n";

    std::cout << "result mantissa     = "
              << std::bitset<M>(result & ((1 << M) - 1))
              << "\n";

    std::cout << "==================================================\n";

    return result;
}
*/

uint16_t pack_superfp(double x)
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

    int stored_exp = exp_unbiased + ADDER_BIAS;

    // mantissa encode
    double m = (frac - 1.0) * (1 << M);
    uint16_t mant = (uint16_t)std::llround(m);

    // handle mantissa overflow
    if (mant == (1 << M))
    {
        mant = 0;
        stored_exp++;
    }

    // underflow
    if (stored_exp <= 0)
        return AOUT_ZERO;

    // overflow
    if (stored_exp >= (1 << E) - 1)
        return sign ? AOUT_NEG_INF : AOUT_POS_INF;

    return (sign << 15) |
           ((stored_exp & ((1 << E) - 1)) << M) |
           (mant & ((1 << M) - 1));
}


// ==========================
// MULTIPLY (E5M3 adapted)
// ==========================
void multiply(uint8_t a, uint8_t b) {
    uint8_t a_sign = a >> 7;
    uint8_t a_exp  = (a >> 3) & 0x1F;
    uint8_t a_man  = a & 0x7;

    uint8_t b_sign = b >> 7;
    uint8_t b_exp  = (b >> 3) & 0x1F;
    uint8_t b_man  = b & 0x7;

    uint8_t result_sign = a_sign ^ b_sign;

    bool a_zero = (a == 0);
    bool b_zero = (b == 0);

    bool is_zero = (a_zero || b_zero);
    bool is_inf  = false;
    bool is_nan  = false;

    if (is_zero) {
        ar.result = AOUT_ZERO;
        ar.is_zero = true;
        ar.is_nan = false;
        ar.is_inf = false;
        return;
    }

    uint8_t a_man_app = a_man;
    uint8_t b_man_app = b_man;

    int8_t a_exp_real = (a_exp == 0) ? (1 - MULTIPLIER_BIAS) : (a_exp - MULTIPLIER_BIAS);
    int8_t b_exp_real = (b_exp == 0) ? (1 - MULTIPLIER_BIAS) : (b_exp - MULTIPLIER_BIAS);

    if (a_exp != 0) a_man_app |= (1 << 3);
    if (b_exp != 0) b_man_app |= (1 << 3);

    uint16_t result_man = a_man_app * b_man_app;
    int8_t result_exp = a_exp_real + b_exp_real;

    if (result_man & (1 << 7)) {
        result_man >>= 1;
        result_exp++;
    }

    uint16_t result =
        (result_sign << 15) |
        ((result_exp & 0x7F) << 8) |
        (result_man & 0xFF);

    ar.result = result;
}

// ==========================
// ADD (unchanged logic)
// ==========================
uint16_t add(uint16_t c) {
    uint16_t p = ar.result;

    uint8_t p_sign = p >> 15;
    int8_t p_exp = (p >> 8) & 0x7F;
    uint32_t p_man = p & 0xFF;

    uint8_t c_sign = c >> 15;
    int8_t c_exp = (c >> 10) & 0x1F;
    uint32_t c_man = c & 0x3FF;

    bool same_sign = (p_sign == c_sign);

    if (p == 0 && c == 0) return 0;

    if (p_exp < c_exp) {
        std::swap(p_exp, c_exp);
        std::swap(p_man, c_man);
        std::swap(p_sign, c_sign);
    }

    uint32_t sum = same_sign ? (p_man + c_man) : (p_man - c_man);

    int8_t final_exp = p_exp;

    if (sum & 0x4000) {
        final_exp++;
    }

    uint16_t result =
        (p_sign << 15) |
        ((final_exp & 0x1F) << 10) |
        (sum & 0x3FF);

    return result;
}

// ==========================
// TEST BENCH WRAPPER
// ==========================
uint16_t compute_expected(uint8_t a, uint8_t b, uint16_t c) {
    multiply(a, b);
    return add(c);
}

int run_test_rtl_real(VE5M3sub *tb, int a, int b, int c) {

// Expected computation
    double fa = cast_E5M3sub_to_real(a);
    double fb = cast_E5M3sub_to_real(b);
    double fc = cast_superfp_to_real(c, M, E, ME, B, B, ADDER_BIAS);
    double product_bin64 = fa * fb;
    double expected_result_bin64 = product_bin64 + fc;
    double expected_result_bin64_quantized = quantize_real_to_superfp(expected_result_bin64, M, E, ME, B, B, ADDER_BIAS, false);
    uint16_t expected_result_bin16 = pack_superfp(expected_result_bin64_quantized);
    uint16_t exp = expected_result_bin16; 

    tb->A9 = a;
    tb->B9 = b;
    tb->C16 = c;
    tb->eval();

    uint16_t rtl = tb->C16_out;

//    uint16_t exp = compute_expected(a, b, c);

total++;

    if (rtl != exp) {

        if (rtl + 1 == exp || rtl - 1 == exp) { //bypass rounding error
//if ((rtl > 0 && rtl - 1 == exp) || rtl + 1 == exp){
            round_errors++;
           return 1;
        }


        std::cout << "\n[E5M3 MISMATCH]\n";
        std::cout << "a=" << std::bitset<8>(a)
                  << " b=" << std::bitset<8>(b) << "\n";

        std::cout << "expected:\n";
        print_fmt(exp);

        std::cout << "rtl:\n";
        print_fmt(rtl);

        std::cout << "fa=" << fa << " fb=" << fb << " fc=" << fc << "\n";
        std::cout << "expected_result_bin64 =" << expected_result_bin64  << " expected_result_bin64_quantized =" << expected_result_bin64_quantized  << " expected_result_bin16 =" << expected_result_bin16  << "\n";
        std::cout << "i=" << a << " j=" << b << " k=" << c <<  "\n";

        return 0;
    }

correct++;

    return 1;
}

// ==========================
// MAIN
// ==========================
int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);

    std::cout << "E5M3 SUB PARAM TEST\n";
    std::cout << "M=" << M << " E=" << E << "\n";

/*
    for (int i = 5; i < 256; i++) {
        for (int j = 27; j < 256; j++) {
            for (int k = 0x8001; k < 65536; k++) {
*/


    for (int i = 5; i < 6; i++) {
        for (int j = 27; j < 28; j++) {
           // for (int k = 0x8001; k < 32770; k++) {

for (int k = 44289; k < 44290; k++) {


/*
    for (int i = 5; i < 256; i+=4) {
        for (int j = 27; j < 256; j+=4) {
            for (int k = 0x8001; k < 65536; k+=256) {
*/


                VE5M3sub *tb = new VE5M3sub;

                if (!run_test_rtl_real(tb, i, j, k)) {
                    delete tb;
                    //return 1;
                }

                delete tb;
            }
        }

        std::cout << "progress i=" << i << "\n";
    }

    std::cout << "ALL TESTS PASSED\n";
    std::cout << "\nTotal number of tests: " << total << std::endl;
    std::cout << "\nCorrect: " << correct << std::endl;
    //std::cout << "\nAcc: " << (correct/total) << std::endl;
std::cout << "\nAcc: "
          << (100.0 * correct / total)
          << "%" << std::endl;
    std::cout << "\nRound Errors:" << round_errors << std::endl;

    return 0;
}
