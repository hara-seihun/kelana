// Symbol isolation only: the included original device reader is unchanged.
#define bf16 original_bf16
#define code2 original_code2
#define query_group original_query_group
#define finish_o original_finish_o
#define launch_conventional launch_original
#define launch_byte_dot unused_original_byte_dot
#include "../kivi-two-bit-dot-query/consumer.hip"
