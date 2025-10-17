

Инструкция по использованию:

1. Сохранить скрипт как deploy-vm.sh и дать права на выполнение:
   chmod +x deploy-vm.sh

2. Убедиться, что:
   - Установлены пакеты: qemu-kvm, libvirt-daemon-system, virtinst, genisoimage
   - Пользователь в группах libvirt и kvm
   - Есть SSH-ключ: ~/.ssh/id_rsa.pub
   - Образ Ubuntu ARM64 лежит в /var/lib/libvirt/images/noble-server-cloudimg-arm64.img

3. Запустить скрипт:
   ./deploy-vm.sh testvm 2048 2 '<h1>Мой сайт из скрипта</h1>'

4. Скрипт выведет:
    ВМ запущена!
    Сайт доступен по адресу: http://192.168.122.10


