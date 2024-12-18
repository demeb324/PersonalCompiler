global int y;
global int z;
global int ans;

program {
    z = 5;
    y = 3;
    call printStr("z = 5, y = 3\n");

    ans = z & y;
    call printStr("z & y = ");
    call printInt(ans);

    ans = z | y;
    call printStr("\nz | y = ");
    call printInt(ans);

    ans = z ^ y;
    call printStr("\nz ^ y = ");
    call printInt(ans);

    ans = -z;
    call printStr("\n-z = ");
    call printInt(ans);

    ans = ~y;
    call printStr("\n~y = ");
    call printInt(ans);
}