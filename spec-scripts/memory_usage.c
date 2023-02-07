#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <unistd.h>
#include <linux/limits.h>

#define RUSAGE_DESTRUCTOR  __attribute__((__destructor__(2222)))

extern RUSAGE_DESTRUCTOR void rusage_dump(void)
{
    const char *logname = getenv("RUSAGE_LOG");
    if (logname == NULL)
        return;
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage) != 0)
    {
        fprintf(stderr, "error: getrusage() failed: %s\n", strerror(errno));
        abort();
    }
    char path[PATH_MAX+1];
    ssize_t len = readlink("/proc/self/exe", path, sizeof(path)-1);
    if (len <= 0 || len >= sizeof(path))
    {
        fprintf(stderr, "error: failed to read link /proc/self/exe: %s\n",
            strerror(errno));
        abort();
    }
    path[len] = '\0';
    FILE *stream = fopen(logname, "a");
    if (stream == NULL)
    {
        fprintf(stderr, "error: failed to open %s: %s\n", logname,
            strerror(errno));
        abort();
    }
    long t = usage.ru_utime.tv_sec * 1000 + usage.ru_utime.tv_usec / 1000 +
             usage.ru_stime.tv_sec * 1000 + usage.ru_stime.tv_usec / 1000;
    fprintf(stream, "%s %lu %lu\n", path, t, usage.ru_maxrss);
    fclose(stream);
}
