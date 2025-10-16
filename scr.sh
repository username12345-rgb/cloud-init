#!/bin/bash
set -e

VM_NAME=${1:-"my-vm"}
RAM=${2:-2048}
VCPUS=${3:-2}
HTML_CONTENT=${4:-"<h1>Hello from $VM_NAME!</h1>"}
IMAGE_PATH="/var/lib/libvirt/images/noble-server-cloudimg-arm64.img"
BASE_DIR="/tmp/cloudinit-$$"

# Создаём временные файлы
mkdir -p "$BASE_DIR"

# user-data
cat > "$BASE_DIR/user-data" <<EOF
#cloud-config
hostname: $VM_NAME
users:
  - name: nikita
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "ssh-rsa FAKE_KEY")
    groups: sudo
    shell: /bin/bash
    lock_passwd: false
    passwd: '$6$rounds=4096$salt\$hashed'  # замените на реальный хэш, если нужно
ssh_pwauth: true
packages:
  - nginx
runcmd:
  - echo '$HTML_CONTENT' > /var/www/html/index.html
  - systemctl enable --now nginx
EOF

# meta-data
cat > "$BASE_DIR/meta-data" <<EOF
instance-id: $VM_NAME
local-hostname: $VM_NAME
EOF

# ISO
genisoimage -output "$BASE_DIR/cloud-data.iso" -volid cidata -joliet -rock \
  "$BASE_DIR/user-data" "$BASE_DIR/meta-data"

# Копируем образ (если нужно)
if [ ! -f "/var/lib/libvirt/images/${VM_NAME}.img" ]; then
  sudo cp "$IMAGE_PATH" "/var/lib/libvirt/images/${VM_NAME}.img"
fi

# Запуск ВМ
virt-install \
  --name "$VM_NAME" \
  --ram "$RAM" \
  --vcpus "$VCPUS" \
  --disk path="/var/lib/libvirt/images/${VM_NAME}.img" \
  --disk path="$BASE_DIR/cloud-data.iso",device=cdrom \
  --os-variant ubuntu24.04 \
  --virt-type kvm \
  --network network=default,model=virtio \
  --import \
  --noautoconsole

# Ждём IP
echo "Waiting for IP..."
sleep 30
IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | awk '/ipv4/ {print $4}' | cut -d'/' -f1)

if [ -n "$IP" ]; then
  echo "VM '$VM_NAME' is running at: http://$IP"
  echo "SSH: ssh nikita@$IP"
else
  echo "Failed to get IP"
  virsh console "$VM_NAME" &
fi

# Очистка
rm -rf "$BASE_DIR"
