namespace swift {
namespace threading {

[[noreturn]] void fatal(const char * /*message*/, ...) {
    __builtin_trap();
}

} // namespace threading
} // namespace swift
