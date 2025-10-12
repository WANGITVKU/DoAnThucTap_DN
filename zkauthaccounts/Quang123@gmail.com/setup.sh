#!/bin/bash
set -e

# Script này được chạy khi người dùng "đăng ký" (setPassword).
# Nhiệm vụ: tạo mạch Circom có password hard-code, compile, setup hệ thống PLONK,
# và cuối cùng chỉ giữ lại các file cần thiết cho việc đăng nhập sau này.

echo "Tạo file circuit.circom..."
cat <<EOT > circuit.circom
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
EOT

echo "Biên dịch circuit..."
# Biên dịch circom -> sinh ra:
#   - circuit.r1cs (hệ constraint dạng nhị phân)
#   - thư mục circuit_js (có circuit.wasm + generate_witness.js)
#   - circuit.sym (bản đồ tín hiệu để debug)
circom circuit.circom --r1cs --wasm --sym
echo "Biên dịch xong."

echo "Xuất R1CS sang JSON..."
# Xuất constraint sang file JSON để dễ đọc (debug). Không cần cho chạy thật.
snarkjs r1cs export json circuit.r1cs circuit.r1cs.json
echo "Xuất JSON xong."

echo "Tạo input.json mẫu..."
# Input thử nghiệm, ở đây cố tình đặt attempt = 1.
# Dùng để test quá trình sinh witness.
cat <<EOT > input.json
{"attempt": 1}
EOT
echo "Tạo input.json xong."

echo "Sinh witness..."
# Dùng circuit.wasm và input.json để sinh witness (witness.wtns).
cd circuit_js
node generate_witness.js circuit.wasm ../input.json ../witness.wtns
cd -
echo "Witness đã sinh."

echo "Thiết lập hệ thống PLONK..."
# Tạo proving key và verifying key cho circuit này từ file pot14_final.ptau.
snarkjs plonk setup circuit.r1cs pot14_final.ptau circuit_final.zkey
echo "Setup PLONK xong."

echo "Xuất verification key..."
# Xuất verification key (dạng JSON) từ zkey. Đây là file công khai để verify proof.
snarkjs zkey export verificationkey circuit_final.zkey verification_key.json
echo "Xuất verification key xong."

echo "Sinh proof thử..."
# Sinh proof thử với witness (attempt=1) để kiểm tra circuit.
# proof.json: bằng chứng
# public.json: kết quả public (isEqual = 0 trong test này)
snarkjs plonk prove circuit_final.zkey witness.wtns proof.json public.json
echo "Proof đã sinh."

echo "Di chuyển wasm và dọn rác..."
# Giữ lại circuit.wasm ở thư mục gốc, xóa thư mục circuit_js.
mv circuit_js/circuit.wasm .
rm -rf circuit_js
echo "Đã di chuyển wasm."

echo "Xoá các file trung gian..."
# Xóa toàn bộ file trung gian không cần thiết để tiết kiệm chỗ và tránh lộ thông tin.
rm -f circuit.r1cs circuit.r1cs.json public.json proof.json witness.wtns circuit.sym input.json
echo "Dọn dẹp xong."

exit 0
