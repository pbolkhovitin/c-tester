#include <stdio.h>

#define NMAX 10

int input(int *a);
void output(const int *a);
void sort(int *a);

int main() {
  int data[NMAX];
  if (!input(data)) {
    printf("n/a");
    return 1;
  }
  sort(data);
  output(data);
  return 0;
}

int input(int *a) {
  for (int i = 0; i < NMAX; i++) {
    if (scanf("%d", &a[i]) != 1) {
      return 0;
    }
  }
  char c;
  if (scanf("%c", &c) == 1 && c != '\n' && c != EOF) {
    return 0;
  }
  return 1;
}

void output(const int *a) {
  for (int i = 0; i < NMAX; i++) {
    printf("%d", a[i]);
    if (i < NMAX - 1) {
      printf(" ");
    }
  }
}

void sort(int *a) {
  for (int i = 0; i < NMAX - 1; i++) {
    for (int j = 0; j < NMAX - i - 1; j++) {
      if (a[j] > a[j + 1]) {
        int temp = a[j];
        a[j] = a[j + 1];
        a[j + 1] = temp;
      }
    }
  }
}
