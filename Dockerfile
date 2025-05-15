# Sử dụng một hình ảnh Ubuntu LTS (Long Term Support) làm cơ sở
# Bạn có thể chọn một phiên bản cụ thể như ubuntu:22.04 hoặc ubuntu:20.04 nếu cần
FROM ubuntu:latest

# Đặt biến môi trường để tránh các lời nhắc tương tác trong quá trình cài đặt gói
ENV DEBIAN_FRONTEND=noninteractive

# Cập nhật danh sách gói, nâng cấp các gói đã cài đặt và cài đặt các gói cần thiết
# Bao gồm 'locales' để tạo và quản lý thông tin địa phương hóa
# và các công cụ khác như ssh, wget, unzip, openssh-server
RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install -y locales && \
    # Tạo locale en_US.UTF-8
    locale-gen en_US.UTF-8 && \
    apt-get install -y ssh wget unzip openssh-server && \
    # Dọn dẹp cache của apt để giảm kích thước hình ảnh
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Thiết lập các biến môi trường cho locale
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Khai báo các đối số build-time cho Ngrok ID và Mật khẩu
ARG ngrokid
ARG Password

# Thiết lập các biến môi trường từ các đối số build-time
ENV Password=${Password}
ENV ngrokid=${ngrokid}

# Tải xuống và giải nén Ngrok
# Chuyển hướng output sang /dev/null để giữ cho log build gọn gàng
RUN wget -O ngrok.zip https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-stable-linux-amd64.zip > /dev/null 2>&1 && \
    unzip ngrok.zip && \
    rm ngrok.zip

# Tạo một script shell để khởi chạy Ngrok và SSHD
# Đổi tên script từ kali.sh thành ubuntu.sh cho phù hợp
RUN echo "#!/bin/bash" > /ubuntu.sh && \
    echo "set -e" >> /ubuntu.sh && \
    echo "" >> /ubuntu.sh && \
    # Cấu hình Ngrok authtoken
    echo "./ngrok config add-authtoken ${ngrokid}" >> /ubuntu.sh && \
    # Chạy Ngrok TCP tunnel cho SSH ở vùng Nhật Bản (jp) trong nền
    echo "./ngrok tcp --region=jp 22 &>/dev/null &" >> /ubuntu.sh && \
    # Tạo thư mục cần thiết cho sshd nếu chưa tồn tại
    echo "mkdir -p /run/sshd" >> /ubuntu.sh && \
    # Chạy SSH daemon ở foreground
    echo "/usr/sbin/sshd -D &" >> /ubuntu.sh && \
    # Thông báo tùy chỉnh
    echo 'echo "By Radhin Development (Ubuntu Version)"' >> /ubuntu.sh && \
    # Giữ container chạy bằng cách đợi tiến trình cuối cùng (sshd)
    echo "wait \$!" >> /ubuntu.sh

# Cấu hình SSHD để cho phép đăng nhập root và xác thực bằng mật khẩu
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    # Đặt mật khẩu cho người dùng root
    echo "root:${Password}" | chpasswd

# Tạo thư mục /run/sshd nếu chưa có và khởi động dịch vụ ssh để đảm bảo cấu hình được áp dụng
# Lưu ý: việc khởi động service ssh ở đây chủ yếu để kiểm tra,
# CMD cuối cùng sẽ chạy sshd ở foreground.
RUN mkdir -p /run/sshd && service ssh start

# Cấp quyền thực thi cho script khởi động
RUN chmod 755 /ubuntu.sh

# Expose các cổng cần thiết
EXPOSE 22 80 8888 8080 443 5130 5131 5132 5133 5134 5135 3306

# Lệnh mặc định để chạy khi container khởi động
CMD ["/ubuntu.sh"]
