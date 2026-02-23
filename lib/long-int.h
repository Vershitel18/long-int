#pragma once

#include <cstddef>
#include <cstdint>

using Word64 = std::uint64_t;

enum class AbiCheckOutcome : std::uint64_t {
  OK = 0,
  RBX_CLOBBERED = 1,
  RBP_CLOBBERED = 2,
  R12_CLOBBERED = 4,
  R13_CLOBBERED = 8,
  R14_CLOBBERED = 16,
  R15_CLOBBERED = 32,
  STACK_MISALIGNED = 64,
};

extern "C" {

void long_int_read(Word64* value, std::size_t length);
void long_int_write(Word64* value, std::size_t length);

void long_int_add(Word64* lhs, const Word64* rhs, std::size_t length);
void long_int_sub(Word64* lhs, const Word64* rhs, std::size_t length);
void long_int_mul(const Word64* lhs, const Word64* rhs, Word64* product, std::size_t length);

AbiCheckOutcome long_int_add_checked(Word64* lhs, const Word64* rhs, std::size_t length);
AbiCheckOutcome long_int_sub_checked(Word64* lhs, const Word64* rhs, std::size_t length);
AbiCheckOutcome long_int_mul_checked(const Word64* lhs, const Word64* rhs, Word64* product, std::size_t length);

}
