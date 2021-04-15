#!/bin/bash

echo "/**********************************/"
echo "/*   Скрипт синхронизации папок   /"
echo "/********************************/"
echo

echo "Выберите операцию: "
echo "1) Синхронизация двух папок"
echo "2) Синхронизация папки и устройства хранения данных"
read -p "Введите номер операции: " operationType

#Проверка введенного номера операции на корректность
while [ ! $operationType -eq 1 ] && [ ! $operationType -eq 2 ]
do
    echo
    echo "Некорректный номер операции, повторите попытку!"
    read -p "Введите номер операции: " operationType
done

# Опция "-e" добавляет переносы на новую строку при
# каждом использовании символа перевода строки "\n"
echo -e "\nВведите путь до первой папки (например: /home/username/firstFolder):"
# Команда чтения read и сохранения пути в переменную firstFolderPath
read firstFolderPath
# Цикл для вывода информации о том, что путь до папки был неверным
    # [ ! -d $1 ] проверка отсутствия папки по указанному пути, 
    # где символ "!" означает логическое отрицание,
    # а команда "-d" проверяет директорию на существование
while [ ! -d "$firstFolderPath" ]
do 
    echo " * Путь до первой папки был введен неверно, повторите попытку:"
    read firstFolderPath
done
echo

if [ $operationType -eq 1 ]
then
    # Чтение и проверка пути для второй папки
    echo "Введите путь до второй папки (например: /home/username/secondFolder):"
    read secondFolderPath
    while [ ! -d "$secondFolderPath" ]
    do 
        echo " * Путь до второй папки был введен неверно, повторите попытку:"
        read secondFolderPath
    done
else
    # Объявление счетчика номера устройства
    deviceCounter=1
    # Объявление массива с путями монтирования устройств
    declare -a arrayOfMountPaths

    # Цикл просмотра данных об устройстве, в котором
    # команда "ls /dev/sd*" показывает список всех устройств
    for device in $(ls /dev/sd*)
    do  
        # Вывод подробных данных о подключенных устройствах через "df -h"
        devInfo=($(df -h "$device"))

        # Объявление переменной для чтения полного пути места монтирования
        mountPath=${devInfo[12]}
        # Нахождение полного пути монтирования устройства
        for (( indexMas = 13; indexMas < ${#devInfo[*]}; indexMas++ ))
        do
            mountPath+=" "${devInfo[$indexMas]}
        done

        # Вывод данных об устройстве
        echo "$deviceCounter) Устройство: $device"
        echo "   - Смонтировано в "$mountPath
        echo "   - Размер: ${devInfo[8]}"
        echo "   - Использовано: ${devInfo[9]}"
        echo "   - Свободно: ${devInfo[10]}"
        echo

        # Замена всех вхождений пробелов в пути монтирования на "\0"
        # чтобы при считывании массива не было неверного вывода пути
        mountPath=${mountPath// /"\0"}
        # Заполнение массива с путями монтирования
        arrayOfMountPaths+=($mountPath)

        # Увеличение счетчика номера устройства
        deviceCounter=$(( $deviceCounter+1 ))
    done

    # Чтение номера устройства и запись в переменную devNum
    read -p "Введите номер устройства для синхронизации: " devNum

    # Замена всех вхождений "\0" на пробел, чтобы пути для папок,
    # состоящих из нескольких слов были доступны при выполнении команд
    deviceMountPath=${arrayOfMountPaths[$devNum-1]//"\0"/" "}
    echo

    # Считывание ответа пользователя по поводу синхронизации папки, лежащей в устройстве
    read -p "Будете ли вы проводить синхронизацию с папкой внутри носителя? (Y/N): " syncFolderAnswer

    # Обработка ответа пользователя, если нужно провести синхронизацию папки в устройстве
    if [ $syncFolderAnswer = "Y" ] || [ $syncFolderAnswer = "y" ]
    then
        # Считывание путя до папки определенного устройства
        echo -e "\nУкажите путь до папки внутри выбранного устройства (например: /FirstFolder)"
        # Проверка существования указанной директории внутри устройства
        while true
        do  
            read -p "Путь до папки: " deviceFolderPath
            # Добавление обратного слэша в начале пути до папки, если он отсутствует
            if [ ! ${deviceFolderPath:0:1} = "/" ]
            then
                deviceFolderPath="/"$deviceFolderPath
            fi

            # Проверка существования пути к указанной папке
            if [ -d "$deviceMountPath$deviceFolderPath" ]
            then
                # Если путь до папки существует, то цикл завершается
                break
            else
                echo
                echo "Указанной папки не существует, повторите попытку!"
            fi
        done
    fi
    secondFolderPath=$deviceMountPath$deviceFolderPath
fi

# Проверка наличия слэша в конце пути до папки и добавление его в случае отсутствия
# ${firstFolderPath: -1} оставляет только 1 символ с конца значения переменной
# Для первой папки
if [ "${firstFolderPath: -1}" != "/" ]
then
    firstFolderPath="$firstFolderPath/"
fi

# Для второй папки
if [ "${secondFolderPath: -1}" != "/" ]
then
    secondFolderPath="$secondFolderPath/"
fi

echo ""
read -p "Хотите провести синхронизацию [Y/N]: " answer
if [ $answer = "Y" ] || [ $answer = "y" ]
then 
    echo -e "\nСинхронизация..."
else
    echo "До встречи!"
    exit
fi

# Определение длины пути до первой папки для нахождения имен файлов
lengthFirstFolderPath=${#firstFolderPath}

while true
do
    # Цикл для переноса совпадающих файлов
    for fileName in $(find "$firstFolderPath")
    do  
        # Отсечение пути до файла: остается только имя файла
        fileName=${fileName:lengthFirstFolderPath}
        # Аргумент "-f" проверяет существование файла с таким же именем во второй папке
        if [ -f "$secondFolderPath$fileName" ]
        then 
            # Объявление массива с данными о дате изменения файла, 
            # команда "ls -g" - показывает информацию о файле
            # Массив с информацией для файла из первой папки
            infoFirstFile=($(ls -g "$firstFolderPath$fileName"))
            # Массив с информацией для файла из второй папки
            infoSecondFile=($(ls -g "$secondFolderPath$fileName"))

            # Вывод пользователю сообщения при не совпадении информации о файлах с одинаковыми именами из первой и второй папки
            if [ "${infoFirstFile[4]} ${infoFirstFile[5]} ${infoFirstFile[6]}" != "${infoSecondFile[4]} ${infoSecondFile[5]} ${infoSecondFile[6]}" ]
            then
                echo -e "\nВ обеих папках находятся файлы с одинаковыми названиями, какой из них оставить?"
                # Вывод информации о файле для первой папки
                echo " * Информация о файле из первой папки:"
                echo "   ** Путь до файла: $firstFolderPath$fileName"
                echo "   ** Месяц изменения файла: ${infoFirstFile[4]}"
                echo "   ** День изменения файла: ${infoFirstFile[5]}"
                echo "   ** Время изменения файла: ${infoFirstFile[6]}"
                # Вывод информации о файле для второй папки
                echo " * Информация о файле из второй папки:"
                echo "   ** Путь до файла: $secondFolderPath$fileName"
                echo "   ** Месяц изменения файла: ${infoSecondFile[4]}"
                echo "   ** День изменения файла: ${infoSecondFile[5]}"
                echo "   ** Время изменения файла: ${infoSecondFile[6]}"
                # Атрибут "-p" позволяет вывести вспомогательную информацию для пользователя
                read -p "Введите 1 или 2, чтобы оставить файл из соответствующей папки: " response
                if [ $response -eq 1 ]
                then
                    # Рекурсивное копирование файла из первой папки во вторую
                    cp -R "$firstFolderPath$fileName" "$secondFolderPath$fileName"
                    # Копируем из второй в первую для изменения мета-данных (Можно закомментить)
                    cp -R "$secondFolderPath$fileName" "$firstFolderPath$fileName"
                elif [ $response -eq 2 ]
                then    
                    #Рекурсивное копирование файла из второй папки в первую
                    cp -R "$secondFolderPath$fileName" "$firstFolderPath$fileName"
                    # Для мета-данных (Можно закомментить)
                    cp -R "$firstFolderPath$fileName" "$secondFolderPath$fileName"
                else continue
                fi
            fi
        fi
    done

    # Рекурсивное копирование файлов (аргумент "-R") без перезаписи существущих файлов (аргумент "-n")
    # Копирование папок и файлов из первой папки во вторую
    cp -n -R "$firstFolderPath." "$secondFolderPath"
    # Копирование папок и файлов из второй папки в первую
    cp -n -R "$secondFolderPath." "$firstFolderPath"

    # Вывод сообщения о завершении синхронизации
    echo -e "Cинхронизация проведена!"
    
    sleep 10;
done
