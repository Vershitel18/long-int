#include "long-int.h"

#include <array>
#include <cstdlib>
#include <iostream>
#include <string_view>
#include <utility>

namespace {

[[noreturn]] void panic() {
  std::exit(EXIT_FAILURE);
}

bool abi_check_outcome_matches(AbiCheckOutcome outcome, AbiCheckOutcome mask) {
  return (std::to_underlying(outcome) & std::to_underlying(mask)) != 0;
}

void handle_abi_check_outcome(AbiCheckOutcome outcome) {
  if (outcome == AbiCheckOutcome::OK) {
    return;
  }

  std::cerr << "ABI violated:" << std::endl;

  if (abi_check_outcome_matches(outcome, AbiCheckOutcome::RBX_CLOBBERED)) {
    std::cerr << "  - RBX clobbered" << std::endl;
  }
  if (abi_check_outcome_matches(outcome, AbiCheckOutcome::RBP_CLOBBERED)) {
    std::cerr << "  - RBP clobbered" << std::endl;
  }
  if (abi_check_outcome_matches(outcome, AbiCheckOutcome::R12_CLOBBERED)) {
    std::cerr << "  - R12 clobbered" << std::endl;
  }
  if (abi_check_outcome_matches(outcome, AbiCheckOutcome::R13_CLOBBERED)) {
    std::cerr << "  - R13 clobbered" << std::endl;
  }
  if (abi_check_outcome_matches(outcome, AbiCheckOutcome::R14_CLOBBERED)) {
    std::cerr << "  - R14 clobbered" << std::endl;
  }
  if (abi_check_outcome_matches(outcome, AbiCheckOutcome::R15_CLOBBERED)) {
    std::cerr << "  - R15 clobbered" << std::endl;
  }
  if (abi_check_outcome_matches(outcome, AbiCheckOutcome::STACK_MISALIGNED)) {
    std::cerr << "  - stack misaligned" << std::endl;
  }

  panic();
}

enum class Operation {
  ADD,
  SUB,
  MUL,
};

Operation parse_op(std::string_view str) {
  if (str == "add") {
    return Operation::ADD;
  } else if (str == "sub") {
    return Operation::SUB;
  } else if (str == "mul") {
    return Operation::MUL;
  } else {
    std::cerr << "Unknown operation" << std::endl;
    panic();
  }
}

struct Options {
  Operation op;
  bool check_abi;
};

Options parse_options(int argc, char** argv) {
  constexpr std::string_view CHECK_ABI_FLAG = "--check-abi";

  if (argc >= 2) {
    Operation op = parse_op(argv[1]);

    if (argc == 2) {
      return {.op = op, .check_abi = false};
    } else if (argc == 3 && argv[2] == CHECK_ABI_FLAG) {
      return {.op = op, .check_abi = true};
    }
  }

  std::cerr << "Usage: " << argv[0] << " <add|sub|mul> [" << CHECK_ABI_FLAG << "]" << std::endl;
  panic();
}

} // namespace

int main(int argc, char** argv) {
  Options opts = parse_options(argc, argv);

  constexpr std::size_t LENGTH = 128;

  std::array<Word64, LENGTH> lhs;
  long_int_read(lhs.data(), LENGTH);

  std::array<Word64, LENGTH> rhs;
  long_int_read(rhs.data(), LENGTH);

  switch (opts.op) {
  case Operation::ADD: {
    if (opts.check_abi) {
      AbiCheckOutcome outcome = long_int_add_checked(lhs.data(), rhs.data(), LENGTH);
      handle_abi_check_outcome(outcome);
    } else {
      long_int_add(lhs.data(), rhs.data(), LENGTH);
    }
    long_int_write(lhs.data(), LENGTH);
    break;
  }
  case Operation::SUB: {
    if (opts.check_abi) {
      AbiCheckOutcome outcome = long_int_sub_checked(lhs.data(), rhs.data(), LENGTH);
      handle_abi_check_outcome(outcome);
    } else {
      long_int_sub(lhs.data(), rhs.data(), LENGTH);
    }
    long_int_write(lhs.data(), LENGTH);
    break;
  }
  case Operation::MUL: {
    std::array<Word64, LENGTH * 2> product;
    if (opts.check_abi) {
      AbiCheckOutcome outcome = long_int_mul_checked(lhs.data(), rhs.data(), product.data(), LENGTH);
      handle_abi_check_outcome(outcome);
    } else {
      long_int_mul(lhs.data(), rhs.data(), product.data(), LENGTH);
    }
    long_int_write(product.data(), LENGTH * 2);
    break;
  }
  }

  return EXIT_SUCCESS;
}
