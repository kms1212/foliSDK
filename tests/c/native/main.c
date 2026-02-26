#include <stdio.h>

#include "byte_stream.h"

StStatus StKrt_Call(StHandle handle __in, uint32_t funcid __in, const void *args __buf, size_t args_size __in, void *result __buf, size_t result_size __in)
{
    return STATUS_UNIMPLEMENTED;
}

StStatus __get_func_id_base(StHandle handle __in, const struct StUuid *uuid __in, uint32_t request_groupid __in, uint32_t request_abiver __in, uint32_t *funcid_base __out, uint32_t *result_abiver __out)
{
    return STATUS_UNIMPLEMENTED;
}

int main(int argc, char **argv, char **envp)
{
    StIfBs_Read(0, NULL, 0, 0, NULL);

    printf("Hello, world!");
    return 0;
}   
