extern int scanf(char *, ...);

/* pointer forward along the stack to a formal parameter */

void rec (int **u, int i) {
  if (i >= 2)
    return;
  else {
    rec(u, i + 1);
    (*u) = &i;
    return;
  }
}

main () {
  int a;
  int *p;
  p = &a;
  scanf("%d", p);
  rec(&p, a);
}
