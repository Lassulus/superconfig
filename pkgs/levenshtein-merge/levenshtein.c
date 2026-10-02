#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int min3(int a, int b, int c) {
    if (a < b) return a < c ? a : c;
    return b < c ? b : c;
}

static int distance(const char *a, const char *b) {
    size_t la = strlen(a), lb = strlen(b);
    int *prev = calloc(lb + 1, sizeof(int));
    if (!prev) exit(1);
    for (size_t j = 0; j <= lb; j++) prev[j] = (int)j;
    for (size_t i = 1; i <= la; i++) {
        int corner = prev[0];
        prev[0] = (int)i;
        for (size_t j = 1; j <= lb; j++) {
            int val = min3(prev[j] + 1, prev[j-1] + 1,
                           corner + (a[i-1] != b[j-1]));
            corner = prev[j];
            prev[j] = val;
        }
    }
    int res = prev[lb];
    free(prev);
    return res;
}

/* Collapse whitespace and trim. Returns malloc'd string. */
static char *normalize(const char *s) {
    while (*s == ' ' || *s == '\t') s++;
    size_t len = strlen(s);
    char *out = malloc(len + 1);
    if (!out) exit(1);
    size_t o = 0;
    int in_space = 0;
    for (size_t i = 0; i < len; i++) {
        if (s[i] == ' ' || s[i] == '\t') {
            if (!in_space && o > 0) out[o++] = ' ';
            in_space = 1;
        } else {
            out[o++] = s[i];
            in_space = 0;
        }
    }
    if (o > 0 && out[o-1] == ' ') o--;
    out[o] = '\0';
    return out;
}

static int fuzzy_match(const char *a, const char *b, double threshold) {
    int dist = distance(a, b);
    size_t la = strlen(a), lb = strlen(b);
    size_t m = la > lb ? la : lb;
    if (m == 0) return 1;
    return (double)dist / (double)m <= threshold;
}

/* Dynamic line array */
struct lines { char **l; size_t n, cap; };

static void lines_init(struct lines *v) {
    v->n = 0; v->cap = 64;
    v->l = malloc(v->cap * sizeof(char *));
    if (!v->l) exit(1);
}

static void lines_push(struct lines *v, char *s) {
    if (v->n == v->cap) {
        v->cap *= 2;
        v->l = realloc(v->l, v->cap * sizeof(char *));
        if (!v->l) exit(1);
    }
    v->l[v->n++] = s;
}

static void read_lines(const char *path, struct lines *v) {
    FILE *f = fopen(path, "r");
    if (!f) return;
    char *line = NULL;
    size_t cap = 0;
    ssize_t len;
    while ((len = getline(&line, &cap, f)) != -1) {
        if (len > 0 && line[len-1] == '\n') line[len-1] = '\0';
        lines_push(v, strdup(line));
    }
    free(line);
    fclose(f);
}

int main(int argc, char **argv) {
    if (argc == 3) {
        printf("%d\n", distance(argv[1], argv[2]));
        return 0;
    }
    if (argc == 5 && strcmp(argv[1], "-t") == 0) {
        double t = atof(argv[2]);
        return fuzzy_match(argv[3], argv[4], t) ? 0 : 1;
    }
    if (argc == 5 && strcmp(argv[1], "merge") == 0) {
        double threshold = atof(argv[4]);

        struct lines target, managed, known;
        lines_init(&target);
        lines_init(&managed);
        lines_init(&known);

        read_lines(argv[3], &target);
        read_lines(argv[2], &managed);

        /* Build normalized index of target lines */
        for (size_t i = 0; i < target.n; i++) {
            char *n = normalize(target.l[i]);
            if (n[0]) lines_push(&known, n);
            else free(n);
        }

        /* Find managed lines missing from target */
        struct lines missing;
        lines_init(&missing);

        for (size_t i = 0; i < managed.n; i++) {
            char *n = normalize(managed.l[i]);
            if (!n[0]) { free(n); continue; }
            int found = 0;
            for (size_t j = 0; j < known.n; j++) {
                if (fuzzy_match(n, known.l[j], threshold)) {
                    found = 1;
                    break;
                }
            }
            if (!found) {
                lines_push(&missing, managed.l[i]);
                lines_push(&known, n);
            } else {
                free(n);
            }
        }

        if (missing.n == 0) return 0;

        FILE *f = fopen(argv[3], "a");
        if (!f) { perror(argv[3]); return 1; }
        fprintf(f, "\n");
        for (size_t i = 0; i < missing.n; i++)
            fprintf(f, "%s\n", missing.l[i]);
        fclose(f);
        return 0;
    }

    fprintf(stderr,
        "usage: levenshtein-merge <a> <b>\n"
        "       levenshtein-merge -t <threshold> <a> <b>\n"
        "       levenshtein-merge merge <managed> <target> <threshold>\n");
    return 2;
}
