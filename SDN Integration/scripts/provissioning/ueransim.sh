git clone https://github.com/aligungr/UERANSIM
sudo apt -y update
sudo apt -y install make g++ libsctp-dev lksctp-tools iproute2
sudo snap -y install cmake --classic
cd UERANSIM || exit
make
cd ..