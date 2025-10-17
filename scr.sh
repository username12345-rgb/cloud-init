

#!/bin/bash
set -e

# Проверка аргументов
if [ "$#" -lt 4 ]; then
  echo "Использование: $0 <имя_ВМ> <RAM_MiB> <vCPUs> <содержимое_страницы>"
  echo "Пример: $0 myvm 2048 2 '<h1>Привет из скрипта!</h1>'"
  exit 1
fi

VM_NAME="$1"
RAM="$2"
VCPUS="$3"
HTML_CONTENT="$4"

# Пути
BASE_DIR="/tmp/cloud-vm-$VM_NAME"
IMAGE_SRC="/var/lib/libvirt/images/noble-server-cloudimg-arm64.img"
IMAGE_DST="$BASE_DIR/disk.img"
ISO_PATH="$BASE_DIR/cloud-data.iso"

# 1. Подготовка директории
mkdir -p "$BASE_DIR"

# 2. Копирование образа (если не существует)
if [ ! -f "$IMAGE_SRC" ]; then
  echo "Ошибка: исходный образ не найден: $IMAGE_SRC"
  echo "Скачайте его: wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img -O $IMAGE_SRC"
  exit 1
fi
cp "$IMAGE_SRC" "$IMAGE_DST"

# 3. Генерация user-data и meta-data
cat > "$BASE_DIR/meta-data" <<EOF
instance-id: $VM_NAME
local-hostname: $VM_NAME
EOF

cat > "$BASE_DIR/user-data" <<EOF
#cloud-config
hostname: $VM_NAME
users:
  - name: nikita
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "ssh-rsa DUMMY_KEY")
    groups: sudo
    shell: /bin/bash
    lock_passwd: true
ssh_pwauth: false
disable_root: true
packages:
  - nginx
runcmd:
  - systemctl enable --now nginx
  - mkdir -p /var/www/html
  - echo '$HTML_CONTENT' > /var/www/html/index.html
EOF

# 4. Создание ISO
genisoimage -output "$ISO_PATH" -volid cidata -joliet -rock \
  "$BASE_DIR/user-data" "$BASE_DIR/meta-data" >/dev/null 2>&1

# 5. Удаление старой ВМ (если есть)
virsh destroy "$VM_NAME" 2>/dev/null || true
virsh undefine "$VM_NAME" --nvram --remove-all-storage 2>/dev/null || true

# 6. Запуск ВМ
virt-install \
  --name "$VM_NAME" \
  --ram "$RAM" \
  --vcpus "$VCPUS" \
  --disk path="$IMAGE_DST" \
  --disk path="$ISO_PATH",device=cdrom \
  --os-variant ubuntu24.04 \
  --virt-type kvm \
  --network network=default,model=virtio \
  --import \
  --noautoconsole

# 7. Ожидание получения IP (до 60 сек)
echo "Ожидание IP-адреса..."
for i in {1..60}; do
  IP=$(virsh domifaddr "$VM_NAME" 2>/dev/null | awk 'NR==3 {print $4}' | cut -d'/' -f1)
  if [ -n "$IP" ] && [ "$IP" != "-" ]; then
    echo "ВМ запущена!"
    echo "Сайт доступен по адресу: http://$IP"
    echo "IP: $IP"
    exit 0
  fi
  sleep 1
done

echo "Не удалось получить IP за 60 секунд."
echo "Проверьте: virsh domifaddr $VM_NAME"
exit 1
