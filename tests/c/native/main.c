#include <stddef.h>

#include <strata/krt.h>
#include <strata/status.h>
#include <strata/handle.h>

#include "sidl/byte_stream.h"

extern StHandle __stdout_handle;

int main(int argc, char **argv, char **envp)
{
    StStatus status;

    status = StIfBs_Write(__stdout_handle, (const uint8_t *)"Hello, world!", 13, 0, NULL);
    if (status != STATUS_SUCCESS) {
        return 1;
    }
    return 0;
}
