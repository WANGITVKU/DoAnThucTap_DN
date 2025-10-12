pragma circom 2.1.6;

# Dùng comparator IsEqual từ circomlib
include "../../node_modules/circomlib/circuits/comparators.circom";

template Main() {
    # Input công khai: attempt (mật khẩu thử khi đăng nhập)
    signal input attempt;
    # Output công khai: isEqual (1 nếu attempt == password, ngược lại 0)
    signal output isEqual;

    # Password thật được đưa vào đây dưới dạng hằng số số nguyên (BigInt).
    # Giá trị này được sinh ra từ password người dùng (encode sang số ASCII).
    var password = 57078963161355783732558168162457896764177255662865468393193442196525420480098;

    component eqChecker = IsEqual();
    attempt ==> eqChecker.in[0];
    password ==> eqChecker.in[1];

    eqChecker.out ==> isEqual;
}

component main = Main();
