#define ARG_UNUSED __attribute__ ((__unused__))
char *apr_md5_encode(const char *pw, const char *salt, char *result, 
                     size_t nbytes);

