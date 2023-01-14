sudo apt install -y dphys-swapfile 
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
sudo apt -y install curl
curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | sudo apt-key add -
sudo apt -y update
sudo apt -y install ros-noetic-desktop-full
sudo apt-get install ros-noetic-rosserial-arduino
sudo apt-get install ros-noetic-rosserial

source /opt/ros/noetic/setup.bash
echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc
source ~/.bashrc

#Step 1: Stop the SWAP

#sudo dphys-swapfile swapoff

#Step 2: Modify the SWAP size

#As root, edit the file /etc/dphys-swapfile and modify the variable CONF_SWAPSIZE:

#sudo nano /etc/dphys-swapfile

#Edit the line and enter decide swap size in MB

#CONF_SWAPSIZE=1024

#Step 3: Create and initialize the file

#Run

#sudo dphys-swapfile setup

#Step 4: Start the SWAP

#sudo dphys-swapfile swapon