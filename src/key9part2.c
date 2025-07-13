#include <stdio.h>

#define LEN 100

int input(int *a, int *len);
void output(const int *a, int len);
void sum(int *buff1, int len1, int *buff2, int len2, int *result,
         int *result_length);
void sub(int *buff1, int len1, int *buff2, int len2, int *result,
         int *result_length);
int compare(int *buff1, int len1, int *buff2, int len2);
void reverse(int *a, int len);

int main() {
  int num1[LEN], num2[LEN];
  int len1 = 0, len2 = 0;
  int result_sum[LEN + 1], result_sub[LEN];
  int sum_len = 0, sub_len = 0;

  if (!input(num1, &len1)) {
    printf("n/a\n");
    return 0;
  }

  if (!input(num2, &len2)) {
    printf("n/a\n");
    return 0;
  }

  sum(num1, len1, num2, len2, result_sum, &sum_len);
  output(result_sum, sum_len);
  printf("\n");

  sub(num1, len1, num2, len2, result_sub, &sub_len);
  if (sub_len == 0) {
    printf("n/a\n");
  } else {
    output(result_sub, sub_len);
    printf("\n");
  }

  return 0;
}

int input(int *a, int *len) {
  int count = 0;
  int temp;
  char c;

  while (scanf("%d%c", &temp, &c) == 2 && count < LEN) {
    if (temp < 0 || temp > 9) {
      return 0;
    }
    a[count++] = temp;
    if (c == '\n' || c == EOF) {
      break;
    }
  }

  if (count == 0 || count > LEN) {
    return 0;
  }

  *len = count;
  return 1;
}

void output(const int *a, int len) {
  for (int i = 0; i < len; i++) {
    printf("%d", a[i]);
    if (i < len - 1) {
      printf(" ");
    }
  }
}

int compare(const int *buff1, int len1, const int *buff2, int len2) {
  if (len1 > len2)
    return 1;
  if (len1 < len2)
    return -1;

  for (int i = 0; i < len1; i++) {
    if (buff1[i] > buff2[i])
      return 1;
    if (buff1[i] < buff2[i])
      return -1;
  }

  return 0;
}

void reverse(int *a, int len) {
  for (int i = 0; i < len / 2; i++) {
    int temp = a[i];
    a[i] = a[len - 1 - i];
    a[len - 1 - i] = temp;
  }
}

void sum(const int *buff1, int len1, const int *buff2, int len2, int *result,
         int *result_length) {
  int temp1[LEN] = {0}, temp2[LEN] = {0};
  int max_len = len1 > len2 ? len1 : len2;

  for (int i = 0; i < len1; i++)
    temp1[i] = buff1[i];
  for (int i = 0; i < len2; i++)
    temp2[i] = buff2[i];

  reverse(temp1, len1);
  reverse(temp2, len2);

  int carry = 0;
  int i;

  for (i = 0; i < max_len || carry; i++) {
    int digit1 = i < len1 ? temp1[i] : 0;
    int digit2 = i < len2 ? temp2[i] : 0;

    int current_sum = digit1 + digit2 + carry;
    result_digit = current_sum % 10;
    carry = current_sum / 10;
  }

  *result_length = i;
  reverse(result, *result_length);
}

void sub(const int *buff1, int len1, const int *buff2, int len2, int *result,
         int *result_length) {
  if (compare(buff1, len1, buff2, len2) < 0) {
    *result_length = 0;
    return;
  }

  int temp1[LEN] = {0}, temp2[LEN] = {0};

  for (int i = 0; i < len1; i++)
    temp1[i] = buff1[i];
  for (int i = 0; i < len2; i++)
    temp2[i] = buff2[i];

  reverse(temp1, len1);
  reverse(temp2, len2);

  int borrow = 0;
  int i;

  for (i = 0; i < len1; i++) {
    int digit1 = temp1[i];
    int digit2 = i < len2 ? temp2[i] : 0;

    int diff = digit1 - digit2 - borrow;
    if (diff < 0) {
      diff += 10;
      borrow = 1;
    } else {
      borrow = 0;
    }

    result[i] = diff;
  }

  while (i > 1 && result[i - 1] == 0) {
    i--;
  }

  *result_length = i;
  reverse(result, *result_length);
}
