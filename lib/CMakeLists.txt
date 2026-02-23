add_library(long-int STATIC)

target_sources(long-int
    PRIVATE
        "checked.asm"
        "common.asm"
        "io.asm"
        "math/add.asm"
        "math/mul.asm"
        "math/sub.asm"
    PUBLIC FILE_SET HEADERS FILES
        "long-int.h"
)
