#include <math.h>
#include <stdio.h>

#define NMAX 30

int input(int *a, int *n);
int is_valid_number(int num, double mean, double sigma);
int search(int *a, int n, double mean, double sigma);
double calculate_mean(const int *a, int n);
double calculate_sigma(const int *a, int n, double mean);

int main() {
    int n, data[NMAX];
    if (!input(data, &n)) {
        printf("n/a\n");
        return 0;
    }

    double mean_val = calculate_mean(data, n);
    double sigma = calculate_sigma(data, n, mean_val);
    int result = search(data, n, mean_val, sigma);

    printf("%d\n", result);
    return 0;
}

int input(int *a, int *n) {
    if (scanf("%d", n) != 1 || *n <= 0 || *n > NMAX) {
        return 0;
    }

    for (int *p = a; p - a < *n; p++) {
        if (scanf("%d", p) != 1) {
            return 0;
        }
    }

    char c;
    if (scanf("%c", &c) == 1 && c != '\n' && c != EOF) {
        return 0;
    }

    return 1;
}

int is_valid_number(int num, double mean, double sigma) {
    return (num != 0) && (num % 2 == 0) && (num >= mean) && (fabs(num - mean) <= 3 * sigma);
}

int search(int *a, int n, double mean, double sigma) {
    for (int i = 0; i < n; i++) {
        if (is_valid_number(a[i], mean, sigma)) {
            return a[i];
        }
    }
    return 0;
}

double calculate_mean(const int *a, int n) {
    double sum = 0.0;
    for (int i = 0; i < n; i++) {
        sum += a[i];
    }
    return sum / n;
}

double calculate_sigma(const int *a, int n, double mean) {
    double variance = 0.0;
    for (int i = 0; i < n; i++) {
        variance += pow(a[i] - mean, 2);
    }
    variance /= n;
    return sqrt(variance);
}
