--[[
    Government Helper 25.4
    Биндер для Правительства Arizona RP
    
    Управление:
    - F2 или /gh - главное меню
    - F6 или /gm - быстрое меню
    - /stop - остановить отыгровку
    - /gupdate - проверить обновления
]]

script_name("Government Helper")
script_author("Chester Williams")
script_version("25.4")

-- Библиотеки
local imgui = require 'mimgui'
local ffi = require 'ffi'
local vkeys = require 'vkeys'
local encoding = require 'encoding'
local sampev = require 'samp.events'  -- Добавлена библиотека для перехвата событий
local dlstatus = require 'moonloader'.download_status -- Добавлена библиотека для скачивания

-- Правильная настройка encoding для конвертации UTF-8 -> CP1251
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Функция конвертации UTF-8 в CP1251 для SAMP чата
local function toCP1251(str)
    return u8:decode(str)
end

-- Функция конвертации CP1251 в UTF-8 для отображения в ImGui
local function toUTF8(str)
    return u8(str)
end

-- Короткие алиасы
local new = imgui.new
local str = ffi.string
local sizeof = ffi.sizeof

-- Добавлены переменные для авто-обновления
local SCRIPT_VERSION = "25.4"
local UPDATE_URL = "https://raw.githubusercontent.com/Nikita2888/Gowerment-Helper/refs/heads/main/government_binder.lua" -- Замени на свой URL
local VERSION_URL = "https://raw.githubusercontent.com/Nikita2888/Gowerment-Helper/refs/heads/main/version.txt" -- Замени на свой URL
local SCRIPT_PATH = thisScript().path
local updateAvailable = false
local latestVersion = ""

-- Состояние окон
local mainWindow = new.bool(false)
local quickWindow = new.bool(false)

-- Размер экрана
local sizeX, sizeY = getScreenResolution()

-- Текстуры
local logoTexture = nil
local bgTexture = nil
local logoLoaded = false
local bgLoaded = false

-- Ожидание клавиши
local waitingForKey = nil
local waitingBindCat = nil
local waitingBindIdx = nil

-- Добавлен буфер для ввода ID игрока в "Мои документы"
local myDocsTargetId = new.char[8]()

-- Добавлена информация об игроке и организации
local playerInfo = {
    name = "",
    sex = "Неизвестно",
    organization = "Неизвестно",
    orgTag = "GOV",
    rank = "Неизвестно",
    rankNumber = 0
}

local checkStats = false  -- Флаг для проверки статистики

-- Настройки
-- Увеличена задержка по умолчанию до 3500мс (3.5 секунды) для Arizona RP антифлуда
local settings = {
    name = "Government",
    sex = 1,
    delay = 3500, -- Увеличено до 3500мс (3.5 секунды) для Arizona RP антифлуда
    dark_style = true
}

-- Добавлена статистика
local statistics = {
    documents = 0,
    passports = 0,
    medcards = 0,
    licenses = 0,
    interviews = 0,
    hired = 0,
    fired = 0,
    marriages = 0,
    divorces = 0,
    fines = 0
}

-- Добавлены заметки
local notes = {}
local noteInput = new.char[512]()
local selectedNote = new.int(0)

-- Текущая вкладка
local currentTab = 1

-- Выбранные элементы
local selectedCategory = new.int(0)
local selectedBind = new.int(0)
local selectedUstavChapter = new.int(0) -- Добавлен для навигации по уставу

-- Меню - текст в UTF-8 для ImGui (шрифт с GetGlyphRangesCyrillic)
-- добавлен пункт "Устав"
local menuItems = {
    {name = "home", nameRu = "Главная"},
    {name = "commands", nameRu = "Команды"},
    {name = "binds", nameRu = "Отыгровки"},
    {name = "mydocs", nameRu = "Мои документы"},
    {name = "meetings", nameRu = "Собрания"},
    {name = "ustav", nameRu = "Устав"},
    {name = "stats", nameRu = "Статистика"},
    {name = "notes", nameRu = "Заметки"},
    {name = "settings", nameRu = "Настройки"},
    {name = "about", nameRu = "О скрипте"}
}

-- Категории
local categories = {
    {data = "greeting", nameRu = "Приветствие"},
    {data = "docs", nameRu = "Документы"},
    {data = "hire", nameRu = "Приём на работу"},
    {data = "fire", nameRu = "Увольнение"},
    {data = "fines", nameRu = "Штрафы"},
    {data = "manage", nameRu = "Управление"},
    {data = "marriage", nameRu = "Браки"},
    {data = "divorce", nameRu = "Разводы"},
    {data = "radio", nameRu = "Рация"},
    {data = "other", nameRu = "Дополнительно"}
}

-- Toggle состояния для биндов
local bindToggles = {}

-- Расширенная таблица имён клавиш с буквами A-Z, цифрами 0-9 и дополнительными клавишами
local keyNames = {
    -- Функциональные клавиши
    [vkeys.VK_F1] = "F1", [vkeys.VK_F2] = "F2", [vkeys.VK_F3] = "F3", [vkeys.VK_F4] = "F4",
    [vkeys.VK_F5] = "F5", [vkeys.VK_F6] = "F6", [vkeys.VK_F7] = "F7", [vkeys.VK_F8] = "F8",
    [vkeys.VK_F9] = "F9", [vkeys.VK_F10] = "F10", [vkeys.VK_F11] = "F11", [vkeys.VK_F12] = "F12",
    -- Цифры (верхний ряд)
    [vkeys.VK_0] = "0", [vkeys.VK_1] = "1", [vkeys.VK_2] = "2", [vkeys.VK_3] = "3",
    [vkeys.VK_4] = "4", [vkeys.VK_5] = "5", [vkeys.VK_6] = "6", [vkeys.VK_7] = "7",
    [vkeys.VK_8] = "8", [vkeys.VK_9] = "9",
    -- Буквы A-Z
    [vkeys.VK_A] = "A", [vkeys.VK_B] = "B", [vkeys.VK_C] = "C", [vkeys.VK_D] = "D",
    [vkeys.VK_E] = "E", [vkeys.VK_F] = "F", [vkeys.VK_G] = "G", [vkeys.VK_H] = "H",
    [vkeys.VK_I] = "I", [vkeys.VK_J] = "J", [vkeys.VK_K] = "K", [vkeys.VK_L] = "L",
    [vkeys.VK_M] = "M", [vkeys.VK_N] = "N", [vkeys.VK_O] = "O", [vkeys.VK_P] = "P",
    [vkeys.VK_Q] = "Q", [vkeys.VK_R] = "R", [vkeys.VK_S] = "S", [vkeys.VK_T] = "T",
    [vkeys.VK_U] = "U", [vkeys.VK_V] = "V", [vkeys.VK_W] = "W", [vkeys.VK_X] = "X",
    [vkeys.VK_Y] = "Y", [vkeys.VK_Z] = "Z",
    -- NumPad
    [vkeys.VK_NUMPAD0] = "Num0", [vkeys.VK_NUMPAD1] = "Num1", [vkeys.VK_NUMPAD2] = "Num2",
    [vkeys.VK_NUMPAD3] = "Num3", [vkeys.VK_NUMPAD4] = "Num4", [vkeys.VK_NUMPAD5] = "Num5",
    [vkeys.VK_NUMPAD6] = "Num6", [vkeys.VK_NUMPAD7] = "Num7", [vkeys.VK_NUMPAD8] = "Num8",
    [vkeys.VK_NUMPAD9] = "Num9",
    [vkeys.VK_MULTIPLY] = "Num*", [vkeys.VK_ADD] = "Num+", [vkeys.VK_SUBTRACT] = "Num-",
    [vkeys.VK_DECIMAL] = "Num.", [vkeys.VK_DIVIDE] = "Num/",
    -- Специальные клавиши
    [vkeys.VK_INSERT] = "Ins", [vkeys.VK_DELETE] = "Del",
    [vkeys.VK_HOME] = "Home", [vkeys.VK_END] = "End",
    [vkeys.VK_PRIOR] = "PgUp", [vkeys.VK_NEXT] = "PgDn",
    [vkeys.VK_TAB] = "Tab", [vkeys.VK_CAPITAL] = "CapsLock",
    [vkeys.VK_SPACE] = "Space", [vkeys.VK_BACK] = "Backspace",
    [vkeys.VK_RETURN] = "Enter",
    -- Стрелки
    [vkeys.VK_UP] = "Up", [vkeys.VK_DOWN] = "Down",
    [vkeys.VK_LEFT] = "Left", [vkeys.VK_RIGHT] = "Right",
    -- Символы
    [vkeys.VK_OEM_1] = ";", [vkeys.VK_OEM_2] = "/", [vkeys.VK_OEM_3] = "`",
    [vkeys.VK_OEM_4] = "[", [vkeys.VK_OEM_5] = "\\", [vkeys.VK_OEM_6] = "]",
    [vkeys.VK_OEM_7] = "'", [vkeys.VK_OEM_COMMA] = ",", [vkeys.VK_OEM_PERIOD] = ".",
    [vkeys.VK_OEM_MINUS] = "-", [vkeys.VK_OEM_PLUS] = "=",
    [0] = "Нет"
}

-- Функция получения названия клавиши с модификаторами
local function getHotkeyName(hotkey)
    if type(hotkey) == "number" then
        return keyNames[hotkey] or "Нет"
    elseif type(hotkey) == "table" then
        if not hotkey.key or hotkey.key == 0 then
            return "Нет"
        end
        local name = ""
        if hotkey.ctrl then name = name .. "Ctrl+" end
        if hotkey.shift then name = name .. "Shift+" end
        if hotkey.alt then name = name .. "Alt+" end
        name = name .. (keyNames[hotkey.key] or "?")
        return name
    end
    return "Нет"
end

-- Функция проверки нажатия горячей клавиши с модификаторами
local function isHotkeyPressed(hotkey)
    if type(hotkey) == "number" then
        return hotkey > 0 and isKeyJustPressed(hotkey)
    elseif type(hotkey) == "table" then
        if not hotkey.key or hotkey.key == 0 then
            return false
        end
        local ctrlOk = not hotkey.ctrl or isKeyDown(vkeys.VK_CONTROL)
        local shiftOk = not hotkey.shift or isKeyDown(vkeys.VK_SHIFT)
        local altOk = not hotkey.alt or isKeyDown(vkeys.VK_MENU)
        return ctrlOk and shiftOk and altOk and isKeyJustPressed(hotkey.key)
    end
    return false
end

-- Функция нормализации hotkey (для совместимости со старым форматом)
local function normalizeHotkey(hotkey)
    if type(hotkey) == "number" then
        return {key = hotkey, ctrl = false, shift = false, alt = false}
    elseif type(hotkey) == "table" then
        return hotkey
    end
    return {key = 0, ctrl = false, shift = false, alt = false}
end

-- Бинды
local binds = {
    greeting = {
        {cmd = "ghello", descRu = "Приветствие", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/me достал папку с документами из кармана",
            "/do Папка с документами в руках.",
            "Здравствуйте! Добро пожаловать в Мэрию.",
            "Чем могу Вам помочь?"
        }},
        {cmd = "gbye", descRu = "Прощание", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "Всего доброго! Хорошего Вам дня!",
            "/me убрал папку с документами в карман"
        }}
    },
    docs = {
        {cmd = "gdoc", descRu = "Запросить документы", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, stat = "documents", lines = {
            "Предъявите, пожалуйста, Ваши документы.",
            "/me взял документы для проверки",
            "/do Документы в руках."
        }},
        {cmd = "gdocret", descRu = "Вернуть документы", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/me вернул документы владельцу",
            "Ваши документы в порядке, держите."
        }},
        {cmd = "gpass", descRu = "Выдать паспорт", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, stat = "passports", lines = {
            "/me открыл базу данных на компьютере",
            "/do База данных открыта.",
            "/me внёс данные гражданина в базу",
            "/me распечатал паспорт на принтере",
            "/do Паспорт распечатан.",
            "Ваш паспорт готов, распишитесь здесь.",
            "/me передал паспорт гражданину"
        }},
        {cmd = "gmedcard", descRu = "Выдать медкарту", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, stat = "medcards", lines = {
            "/me открыл базу данных медицинских карт",
            "/do База данных открыта.",
            "/me внёс данные гражданина в базу",
            "/me распечатал медицинскую карту",
            "/do Медкарта распечатана.",
            "Ваша медицинская карта готова.",
            "/me передал медкарту гражданину"
        }},
        {cmd = "glicense", descRu = "Выдать лицензию", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, stat = "licenses", lines = {
            "/me открыл базу данных лицензий",
            "/do База данных открыта.",
            "/me проверил данные заявителя",
            "/me оформил лицензию",
            "/do Лицензия готова.",
            "Ваша лицензия оформлена, держите.",
            "/me передал лицензию гражданину"
        }}
    },
    hire = {
        {cmd = "ghire1", descRu = "Начало собеседования", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, stat = "interviews", lines = {
            "Здравствуйте! Вы на собеседование?",
            "Присаживайтесь, пожалуйста.",
            "/me достал папку с анкетами",
            "/do Папка с анкетами в руках.",
            "Расскажите немного о себе."
        }},
        {cmd = "ghire2", descRu = "Вопросы", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "Почему Вы хотите работать в Правительстве?",
            "Какой у Вас опыт работы?",
            "Знакомы ли Вы с Уставом организации?"
        }},
        {cmd = "ghire3", descRu = "Принятие", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, stat = "hired", lines = {
            "Поздравляю! Вы приняты на работу.",
            "/me занёс данные сотрудника в базу",
            "/do Данные занесены в базу.",
            "Добро пожаловать в нашу команду!"
        }},
        {cmd = "ghire4", descRu = "Отказ", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "К сожалению, Вы нам не подходите.",
            "Попробуйте подать заявку позже.",
            "Всего доброго!"
        }}
    },
    fire = {
        {cmd = "gfire", descRu = "Увольнение", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, stat = "fired", lines = {
            "/me открыл личное дело сотрудника",
            "/do Личное дело открыто.",
            "Вы уволены из Правительства.",
            "/me удалил данные сотрудника из базы",
            "Сдайте рабочее имущество."
        }}
    },
    fines = {
        {cmd = "gfine", descRu = "Выписать штраф", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, stat = "fines", lines = {
            "/me достал бланк штрафа",
            "/do Бланк штрафа в руках.",
            "/me заполнил данные нарушителя",
            "/me выписал штраф",
            "Вам выписан штраф. Оплатите его в течение 24 часов."
        }},
        {cmd = "gfwarn", descRu = "Предупреждение", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "Вы нарушаете закон!",
            "В случае повторного нарушения будет выписан штраф."
        }}
    },
    manage = {
        {cmd = "gwarn", descRu = "Выговор", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/me открыл личное дело сотрудника",
            "Вам объявляется выговор за нарушение.",
            "/me сделал запись в личном деле"
        }},
        {cmd = "gup", descRu = "Повышение", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/me открыл личное дело сотрудника",
            "Поздравляю с повышением!",
            "/me изменил должность в базе данных"
        }},
        {cmd = "gdown", descRu = "Понижение", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/me открыл личное дело сотрудника",
            "Вы понижены в должности.",
            "/me изменил должность в базе данных"
        }}
    },
    marriage = {
        {cmd = "gmar1", descRu = "Начало брака", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/me открыл книгу регистрации браков",
            "/do Книга регистрации открыта.",
            "Уважаемые молодожёны!",
            "Сегодня мы собрались здесь, чтобы зарегистрировать ваш брак."
        }},
        {cmd = "gmar2", descRu = "Вопрос жениху", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "Согласны ли Вы взять в жёны эту женщину?",
            "Обещаете ли любить её в горе и в радости?"
        }},
        {cmd = "gmar3", descRu = "Вопрос невесте", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "Согласны ли Вы стать женой этого мужчины?",
            "Обещаете ли любить его в горе и в радости?"
        }},
        {cmd = "gmar4", descRu = "Завершение брака", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, stat = "marriages", lines = {
            "Объявляю Вас мужем и женой!",
            "/me поставил печать в свидетельстве",
            "/me вручил свидетельство о браке",
            "Поздравляю! Можете поцеловать друг друга."
        }}
    },
    divorce = {
        {cmd = "gdiv1", descRu = "Начало развода", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/me открыл книгу регистрации разводов",
            "/do Книга регистрации открыта.",
            "Вы уверены, что хотите расторгнуть брак?"
        }},
        {cmd = "gdiv2", descRu = "Оформление развода", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, stat = "divorces", lines = {
            "/me заполнил заявление о разводе",
            "/me поставил печать на документе",
            "Ваш брак официально расторгнут.",
            "/me выдал свидетельство о разводе"
        }}
    },
    radio = {
        {cmd = "gron", descRu = "Включить рацию", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/me включил рацию",
            "/do Рация включена и работает."
        }},
        {cmd = "groff", descRu = "Выключить рацию", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/me выключил рацию",
            "/do Рация выключена."
        }},
        {cmd = "grcode", descRu = "Код 1", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/r Код 1 - Прибыл на место работы."
        }}
    },
    other = {
        {cmd = "ghelp", descRu = "Помощь", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "Чем я могу Вам помочь?",
            "Я готов ответить на Ваши вопросы."
        }},
        {cmd = "gafk", descRu = "Отошёл", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/me повесил табличку 'Перерыв'",
            "/do На столе табличка 'Перерыв'."
        }},
        {cmd = "gback", descRu = "Вернулся", enabled = true, hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
            "/me убрал табличку со стола",
            "/do Сотрудник готов к работе."
        }}
    }
}

-- Отыгровки для ПОКАЗА своих документов (а не получения)
local myDocsBinds = {
    {name = "Показать паспорт", cmd = "gshowpass", hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
        "/me достал паспорт из кармана",
        "/do Паспорт в руках.",
        "/me показал паспорт человеку напротив",
        "/showpass {id}"
    }},
    {name = "Показать медкарту", cmd = "gshowmed", hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
        "/me достал медицинскую карту",
        "/do Медкарта в руках.",
        "/me показал медкарту человеку напротив",
        "/showmc {id}"
    }},
    {name = "Показать лицензии", cmd = "gshowlic", hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
        "/me достал лицензии из кармана",
        "/do Лицензии в руках.",
        "/me показал лицензии человеку напротив",
        "/showlic {id}"
    }},
    {name = "Показать удостоверение", cmd = "gshowid", hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
        "/me достал удостоверение из кармана",
        "/do Удостоверение сотрудника Правительства в руках.",
        "/me раскрыл удостоверение и показал человеку напротив"
    }},
    {name = "Показать все документы", cmd = "gshowall", hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
        "/me достал папку с документами из кармана",
        "/do Папка с документами в руках.",
        "/me показал паспорт",
        "/showpass {id}",
        "/me показал медицинскую карту",
        "/showmc {id}",
        "/me показал лицензии",
        "/showlic {id}",
        "Вот все мои документы."
    }},
    {name = "Передать документы", cmd = "ggivedoc", hotkey = {key = 0, ctrl = false, shift = false, alt = false}, lines = {
        "/me достал документы из кармана",
        "/do Документы в руках.",
        "/me передал документы человеку напротив",
        "/todo Возьмите*передавая документы"
    }}
}

-- добавлен Устав Правительства штата Спэйс
local ustavChapters = {
    {
        title = "ГЛАВА I. ОБЩИЕ ПОЛОЖЕНИЯ",
        content = {
            "1.1. Устав правительства - нормативно-правовой акт, регламентирующий и регулирующий обязанности и порядок работы сотрудников правительства.",
            "1.2. Целью устава правительства является установление порядка, обязанностей, запретов и прав сотрудников.",
            "1.3. За нарушение устава предусмотрены дисциплинарные взыскания от устного предупреждения вплоть до занесения в черный список правительства.",
            "1.4. Незнание устава правительства не освобождает от ответственности.",
            "1.5. Контроль за соблюдением устава правительства осуществляет Губернатор и Вице-Губернатор.",
            "1.6. Каждый сотрудник обязан ознакомиться с уставом правительства.",
            "1.7. Изменения устава правительства возможны только в соответствии с Конституцией штата Спейс."
        }
    },
    {
        title = "ГЛАВА II. ОБЯЗАННОСТИ СОТРУДНИКА",
        content = {
            "2.1. Сотрудник правительства обязан знать устав правительства, а также законодательство штата.",
            "2.2. Сотрудник правительства обязан соблюдать субординацию.",
            "2.3. Сотрудник правительства обязан выполнять приказы руководства.",
            "2.4. Сотрудник правительства обязан носить форму при исполнении.",
            "2.5. Сотрудник правительства обязан вести себя корректно с гражданами.",
            "2.6. Сотрудник правительства обязан предоставлять качественные услуги.",
            "2.7. Сотрудник правительства обязан соблюдать рабочий график."
        }
    },
    {
        title = "ГЛАВА III. ЗАПРЕТЫ",
        content = {
            "3.1. Запрещено брать взятки.",
            "3.2. Запрещено злоупотреблять служебным положением.",
            "3.3. Запрещено разглашать конфиденциальную информацию.",
            "3.4. Запрещено использовать нецензурную лексику.",
            "3.5. Запрещено оскорблять граждан и коллег.",
            "3.6. Запрещено появляться на работе в нетрезвом состоянии.",
            "3.7. Запрещено покидать рабочее место без разрешения.",
            "3.8. Запрещено использовать служебный транспорт в личных целях.",
            "3.9. AFK правила:",
            "     Разрешено: до 10 мин в раздевалке, до 2 мин вне раздевалки",
            "     AFK no ESC полностью запрещён!",
            "3.10. AFK вне рабочего времени разрешён только в раздевалке или личных местах.",
            "3.11. Запрещено выводить людей из мэрии без оснований (ст. 6.2).",
            "3.12. Запрещено нарушать стиль речи и этику общения.",
            "3.13. Запрещено пропускать собрания без уведомления.",
            "3.14. Запрещено нарушать законодательство штата Спейс.",
            "3.15. Запрещено использовать резиновую дубинку без оснований (ст. 6.2).",
            "3.16. Запрещено находиться без бейджика при исполнении.",
            "3.17. Запрещено игнорировать строевые построения.",
            "3.18. Запрещено передвигаться на личном авто не из реестра служебных.",
            "3.19. Запрещено не появляться на работе 10+ дней.",
            "3.20. Сотрудники могут быть уволены Губернатором за нарушения."
        }
    },
    {
        title = "ГЛАВА IV. ГРАФИК РАБОЧЕГО ДНЯ",
        content = {
            "Понедельник - Пятница: 10:00 - 22:00",
            "Суббота: 11:00 - 22:00",
            "Воскресенье: 12:00 - 22:00",
            "",
            "Обеденный перерыв: 13:00 - 14:00"
        }
    },
    {
        title = "ГЛАВА V. ПРАВИЛА ОКАЗАНИЯ УСЛУГ",
        content = {
            "5.1. Сотрудник обязан:",
            "     - Корректно и вежливо предоставлять услуги",
            "     - Не навязывать услуги против воли граждан",
            "     - Не вводить в заблуждение о стоимости и условиях",
            "",
            "5.2. Сотруднику запрещается:",
            "     - Использовать обман или запугивание",
            "     - Предлагать услуги за неуставное вознаграждение",
            "     - Рекламировать услуги в неположенных местах",
            "     - Использовать ненормативную лексику",
            "     - Мешать гражданам, обслуживающимся другими сотрудниками",
            "",
            "5.3. При оказании услуг сотрудник обязан:",
            "     - Соблюдать деловой стиль речи",
            "     - Называть своё имя, должность и организацию"
        }
    },
    {
        title = "ГЛАВА VI. НАХОЖДЕНИЕ В ЗДАНИИ",
        content = {
            "6.1. При нарушениях ст. 5.2 сотрудник вправе вывести нарушителя.",
            "",
            "6.2. Основания для вывода за территорию:",
            "     - Неадекватное поведение",
            "     - Проникновение на закрытую территорию",
            "     - Оскорбление сотрудников",
            "     - Использование нецензурной лексики",
            "     - Мелкое хулиганство",
            "",
            "6.3. При необходимости разрешено применять резиновую дубинку.",
            "",
            "6.4. Закрытые территории для посетителей:",
            "     - Раздевалка",
            "     - Третий этаж мэрии",
            "     - Зал суда"
        }
    },
    {
        title = "ГЛАВА VII. ДРЕСС-КОД",
        content = {
            "7.1. Внешний вид должен соответствовать деловому стилю.",
            "7.2. Одежда должна быть строгой и аккуратной.",
            "",
            "7.3. Для мужчин:",
            "     - Классический костюм (пиджак и брюки)",
            "     - Рубашка светлых оттенков",
            "     - Галстук",
            "     - Закрытая обувь тёмных тонов",
            "",
            "7.4. Для женщин:",
            "     - Классический костюм или деловое платье",
            "     - Обувь на среднем или низком каблуке",
            "     - Сдержанные аксессуары",
            "",
            "7.5. Запрещено носить аксессуары, не предусмотренные ст. 7.6.",
            "",
            "7.6. Список разрешённых аксессуаров для сотрудников:",
            "     - Усы",
            "     - Очки",
            "     - Часы",
            "     - Медицинская маска, респиратор",
            "     - Любые аксессуары на грудь",
            "     - Классические шары (не магические)",
            "     - Попугай на плечо",
            "     - Цилиндр",
            "     - Повязка на шею",
            "     - Дреды",
            "     - Монокль",
            "     - Борода",
            "     - Парик",
            "     - Новогодняя шапка (только в новогодний период: Декабрь, Январь, Февраль)",
            "     - Новогодний шарф (только в новогодний период: Декабрь, Январь, Февраль)"
        }
    },
    {
        title = "ГЛАВА VIII. СУБОРДИНАЦИЯ",
        content = {
            "8.1. Сотрудник обязан соблюдать субординацию.",
            "8.2. Сотрудник должен общаться на \"Вы\" с каждымmathbb{#}гражданином.",
            "8.3. Сотрудник должен уважительно относиться к каждому гражданину.",
            "8.4. Сотрудник обязан составлять мысли чётко и ясно.",
            "8.5. Сотруднику запрещены нецензурные выражения."
        }
    },
    {
        title = "ГЛАВА IX. ВНУТРЕННЯЯ СТРУКТУРА",
        content = {
            "9.1. Отдел коллегии адвокатов - внутренний отдел правительства.",
            "",
            "В обязанности адвокатуры входит:",
            "     - Предоставление юридических услуг заключённым",
            "     - Защита прав и свобод граждан штата Спэйс"
        }
    },
    {
        title = "ГЛАВА X. СЛУЖЕБНЫЙ ТРАНСПОРТ",
        content = {
            "10.1. Служебный транспорт предоставляется для выполнения обязанностей.",
            "",
            "10.2. Правила пользования:",
            "     - Парковать транспорт в начальное место",
            "     - Поддерживать состояние транспорта",
            "     - Запрещено использование в личных целях",
            "     - Запрещено оставлять в неположенных местах",
            "",
            "10.3. Служебный транспорт:",
            "     - Range Rover SVA - с 6-й должности",
            "     - Toyota Land Cruiser VXR V8 - с 7-й должности",
            "     - Volkswagen Passat - с 5-й должности",
            "     - Kia Sportage - с 3-й должности",
            "     - Вертолёт Maverick - с 6-й должности"
        }
    },
    {
        title = "ГЛАВА XI. ВСТУПЛЕНИЕ В СИЛУ",
        content = {
            "11.1. Устав правительства вступает в силу с 30.08.2025.",
            "Все его положения применяются с этой даты."
        }
    }
}

-- Добавлен флаг для остановки отыгровки
local isBindPlaying = false
local stopBind = false

-- Инициализация toggles
local function initToggles()
    for catName, catBinds in pairs(binds) do
        bindToggles[catName] = {}
        for i, bind in ipairs(catBinds) do
            bindToggles[catName][i] = new.bool(bind.enabled)
        end
    end
end

-- Цвета темы
local colors = {
    accent = imgui.ImVec4(0.29, 0.56, 0.85, 1.0),
    accentHover = imgui.ImVec4(0.35, 0.62, 0.90, 1.0),
    sidebar = imgui.ImVec4(0.10, 0.10, 0.12, 0.95),
    sidebarItem = imgui.ImVec4(0.15, 0.15, 0.18, 1.0),
    sidebarHover = imgui.ImVec4(0.20, 0.20, 0.25, 1.0),
    content = imgui.ImVec4(0.12, 0.12, 0.15, 0.90),
    header = imgui.ImVec4(0.14, 0.14, 0.17, 0.95),
    text = imgui.ImVec4(0.90, 0.90, 0.90, 1.0),
    textDark = imgui.ImVec4(0.60, 0.60, 0.65, 1.0),
    green = imgui.ImVec4(0.30, 0.75, 0.40, 1.0),
    red = imgui.ImVec4(0.85, 0.30, 0.30, 1.0),
    orange = imgui.ImVec4(0.85, 0.55, 0.20, 1.0),
    gold = imgui.ImVec4(0.85, 0.70, 0.20, 1.0),
    purple = imgui.ImVec4(0.60, 0.40, 0.80, 1.0),
    border = imgui.ImVec4(0.20, 0.20, 0.25, 1.0)
}

-- Путь к файлам
local configPath = getWorkingDirectory() .. "\\GOV Helper\\"

-- Функция для перевода ника на русский
local function translateNick(nick)
    if not nick then return "" end
    return nick:gsub("_", " ")
end

-- Загрузка и сохранение настроек
local function saveConfig()
    local f = io.open(configPath .. "config.json", "w")
    if f then
        f:write("{\n")
        f:write('  "delay": ' .. settings.delay .. ',\n')
        f:write('  "sex": ' .. settings.sex .. ',\n')
        -- Информация об игроке
        f:write('  "player_name": "' .. playerInfo.name .. '",\n')
        f:write('  "player_sex": "' .. playerInfo.sex .. '",\n')
        f:write('  "player_org": "' .. playerInfo.organization .. '",\n')
        f:write('  "player_org_tag": "' .. playerInfo.orgTag .. '",\n')
        f:write('  "player_rank": "' .. playerInfo.rank .. '",\n')
        f:write('  "player_rank_num": ' .. playerInfo.rankNumber .. ',\n')
        -- Статистика
        f:write('  "stats_documents": ' .. statistics.documents .. ',\n')
        f:write('  "stats_passports": ' .. statistics.passports .. ',\n')
        f:write('  "stats_medcards": ' .. statistics.medcards .. ',\n')
        f:write('  "stats_licenses": ' .. statistics.licenses .. ',\n')
        f:write('  "stats_interviews": ' .. statistics.interviews .. ',\n')
        f:write('  "stats_hired": ' .. statistics.hired .. ',\n')
        f:write('  "stats_fired": ' .. statistics.fired .. ',\n')
        f:write('  "stats_marriages": ' .. statistics.marriages .. ',\n')
        f:write('  "stats_divorces": ' .. statistics.divorces .. ',\n')
        f:write('  "stats_fines": ' .. statistics.fines .. '\n')
        f:write("}")
        f:close()
    end
    
    -- Сохранение заметок
    local nf = io.open(configPath .. "notes.txt", "w")
    if nf then
        for _, note in ipairs(notes) do
            nf:write(note .. "\n---NOTE_SEPARATOR---\n")
        end
        nf:close()
    end
end

local function loadConfig()
    local f = io.open(configPath .. "config.json", "r")
    if f then
        local content = f:read("*all")
        f:close()
        -- Простой парсинг
        local delay = content:match('"delay":%s*(%d+)')
        local sex = content:match('"sex":%s*(%d+)')
        if delay then settings.delay = tonumber(delay) end
        if sex then settings.sex = tonumber(sex) end
        
        -- Информация об игроке
        local pname = content:match('"player_name":%s*"([^"]*)"')
        local psex = content:match('"player_sex":%s*"([^"]*)"')
        local porg = content:match('"player_org":%s*"([^"]*)"')
        local porgtag = content:match('"player_org_tag":%s*"([^"]*)"')
        local prank = content:match('"player_rank":%s*"([^"]*)"')
        local pranknum = content:match('"player_rank_num":%s*(%d+)')
        
        if pname then playerInfo.name = pname end
        if psex then playerInfo.sex = psex end
        if porg then playerInfo.organization = porg end
        if porgtag then playerInfo.orgTag = porgtag end
        if prank then playerInfo.rank = prank end
        if pranknum then playerInfo.rankNumber = tonumber(pranknum) end
        
        -- Статистика
        local function getStat(name)
            local val = content:match('"stats_' .. name .. '":%s*(%d+)')
            return val and tonumber(val) or 0
        end
        statistics.documents = getStat("documents")
        statistics.passports = getStat("passports")
        statistics.medcards = getStat("medcards")
        statistics.licenses = getStat("licenses")
        statistics.interviews = getStat("interviews")
        statistics.hired = getStat("hired")
        statistics.fired = getStat("fired")
        statistics.marriages = getStat("marriages")
        statistics.divorces = getStat("divorces")
        statistics.fines = getStat("fines")
    end
    
    -- Загрузка заметок
    local nf = io.open(configPath .. "notes.txt", "r")
    if nf then
        local content = nf:read("*all")
        nf:close()
        notes = {}
        for note in content:gmatch("(.-)\n%-%-%-NOTE_SEPARATOR%-%-%-\n") do
            if note ~= "" then
                table.insert(notes, note)
            end
        end
    end
end

-- Утилиты
local function get_closest_player_id()
    local minDist = 9999
    local closestId = -1
    local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
    for i = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(i) and i ~= select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) then
            local res, ped = sampGetCharHandleBySampPlayerId(i)
            if res then
                local x, y, z = getCharCoordinates(ped)
                local dist = getDistanceBetweenCoords3d(myX, myY, myZ, x, y, z)
                if dist < minDist then
                    minDist = dist
                    closestId = i
                end
            end
        end
    end
    return closestId
end

-- Отправка бинда с учётом статистики
local function sendBind(lines, statName)
    lua_thread.create(function()
        isBindPlaying = true
        stopBind = false
        for lineIndex, line in ipairs(lines) do
            if stopBind then
                break
            end
            
            -- Задержка ПЕРЕД сообщением, но НЕ перед первым
            if lineIndex ~= 1 then
                wait(settings.delay)
            end
            
            if not stopBind then
                local text = line
                local closest = get_closest_player_id()
                if closest >= 0 then
                    text = text:gsub("{id}", closest)
                    text = text:gsub("{name}", sampGetPlayerNickname(closest):gsub("_", " "))
                end
                -- Подстановка информации об игроке
                text = text:gsub("{myname}", playerInfo.name)
                text = text:gsub("{myorg}", playerInfo.organization)
                text = text:gsub("{myrank}", playerInfo.rank)
                -- Конвертируем UTF-8 в CP1251 для SAMP чата
                sampSendChat(toCP1251(text))
            end
        end
        isBindPlaying = false
        -- Увеличиваем статистику
        if statName and statistics[statName] ~= nil then
            statistics[statName] = statistics[statName] + 1
            saveConfig()
        end
    end)
end

-- Перехват диалога статистики для определения организации и ранга
function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    -- Полностью переписал парсинг для CP1251 текста
    if dialogId == 235 then
        print("[v0] Dialog 235 found, parsing stats...")
        
        -- Текст приходит в CP1251, конвертируем в UTF-8 для правильного поиска
        local textUTF8 = toUTF8(text)
        
        -- Собираем все значения в квадратных скобках из UTF-8 текста
        local bracketValues = {}
        for value in textUTF8:gmatch("%[([^%]]+)%]") do
            -- Пропускаем цветовые коды (6 hex символов)
            if not value:match("^%x%x%x%x%x%x$") then
                table.insert(bracketValues, value)
                print("[v0] Found bracket value: " .. value)
            end
        end
        
        -- Имя - первое значение (ник игрока)
        if bracketValues[1] then
            playerInfo.name = translateNick(bracketValues[1])
            print("[v0] Name: " .. playerInfo.name)
        end
        
        -- Пол - второе значение
        if bracketValues[2] then
            local sex = bracketValues[2]:gsub("%s+", "") -- убираем пробелы
            if sex ~= "" then
                playerInfo.sex = sex
                print("[v0] Sex: " .. playerInfo.sex)
            end
        end
        
        -- Ищем ОРГАНИЗАЦИЮ по ключевому слову (это фракция, а не работа)
        local orgFound = false
        local orgStart = textUTF8:find("Организация:")
        if orgStart then
            local afterOrg = textUTF8:sub(orgStart)
            local org = afterOrg:match("%[([^%]]+)%]")
            if org and not org:match("^%x%x%x%x%x%x$") then
                local orgValue = org:gsub("%s+$", ""):gsub("^%s+", "") -- trim
                playerInfo.organization = orgValue
                orgFound = true
                print("[v0] Organization: " .. playerInfo.organization)
                
                -- Если организация "Не имеется" - значит игрок не в организации
                if orgValue == "Не имеется" or orgValue == "No organization" or orgValue == "" then
                    playerInfo.rank = "Нет"
                    playerInfo.rankNumber = 0
                    playerInfo.orgTag = ""
                    print("[v0] No organization - rank set to 'Нет'")
                else
                    -- Определяем тег организации
                    if orgValue:find("равительство") or orgValue:find("Government") or orgValue:find("Мэрия") then
                        playerInfo.orgTag = "GOV"
                    elseif orgValue:find("олиц") or orgValue:find("Police") or orgValue:find("LSPD") or orgValue:find("LVPD") or orgValue:find("SFPD") then
                        playerInfo.orgTag = "PD"
                    elseif orgValue:find("ольниц") or orgValue:find("Hospital") or orgValue:find("Медик") then
                        playerInfo.orgTag = "EMS"
                    elseif orgValue:find("рми") or orgValue:find("Army") then
                        playerInfo.orgTag = "ARMY"
                    elseif orgValue:find("ФБР") or orgValue:find("FBI") then
                        playerInfo.orgTag = "FBI"
                    else
                        playerInfo.orgTag = "ORG"
                    end
                    
                    -- Ищем ДОЛЖНОСТЬ только если есть организация
                    -- Ищем "Должность:" в тексте (это ранг в организации)
                    local rankStart = textUTF8:find("Должность:")
                    if rankStart then
                        local afterRank = textUTF8:sub(rankStart)
                        local rank = afterRank:match("%[([^%]]+)%]")
                        if rank and not rank:match("^%x%x%x%x%x%x$") then
                            playerInfo.rank = rank:gsub("%s+$", ""):gsub("^%s+", "")
                            print("[v0] Rank (from Должность): " .. playerInfo.rank)
                        end
                    end
                    
                    -- Ищем номер ранга
                    local rankNumStart = textUTF8:find("Ранг:")
                    if rankNumStart then
                        local afterRankNum = textUTF8:sub(rankNumStart)
                        local rankNum = afterRankNum:match("%[(%d+)%]")
                        if rankNum then
                            playerInfo.rankNumber = tonumber(rankNum) or 0
                            print("[v0] Rank number: " .. playerInfo.rankNumber)
                        end
                    end
                end
            end
        end
        
        -- Если организация не найдена, ищем по значениям
        if not orgFound or playerInfo.organization == "Неизвестно" or playerInfo.organization == "" then
            for i, val in ipairs(bracketValues) do
                if val:find("равительство") or val:find("Мэрия") or val:find("Government")
                    or val:find("Police") or val:find("Полиция") or val:find("Больница")
                    or val:find("Не имеется") or val:find("No organization") then
                    playerInfo.organization = val:gsub("%s+$", ""):gsub("^%s+", "")
                    print("[v0] Organization (by search): " .. val)
                    
                    -- Если "Не имеется" - нет ранга
                    if val == "Не имеется" or val == "No organization" then
                        playerInfo.rank = "Нет"
                        playerInfo.rankNumber = 0
                    end
                    break
                end
            end
        end
        
        -- НЕ используем "Работа:" для определения ранга - это подработка!
        -- "Работа:" это типа "Дальнобойщик", "Таксист" - НЕ связано с организацией
        
        -- Сохраняем данные
        saveConfig()
        print("[v0] Player info saved!")
    end
end

-- Применение темы с кириллическим шрифтом
imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    
    -- Загрузка шрифта с кириллицей
    local fontPath = (os.getenv("WINDIR") or "C:\\Windows") .. "\\Fonts\\trebucbd.ttf"
    if doesFileExist(fontPath) then
        imgui.GetIO().Fonts:Clear()
        imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath, 16.0, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
    else
        fontPath = (os.getenv("WINDIR") or "C:\\Windows") .. "\\Fonts\\arial.ttf"
        if doesFileExist(fontPath) then
            imgui.GetIO().Fonts:Clear()
            imgui.GetIO().Fonts:AddFontFromFileTTF(fontPath, 16.0, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
        end
    end
    
    -- Добавлена загрузка текстуры логотипа
    local logoPath = configPath .. "logo.jpg"
    if doesFileExist(logoPath) then
        logoTexture = imgui.CreateTextureFromFile(logoPath)
        if logoTexture then
            logoLoaded = true
        end
    end
    
    -- Добавлена загрузка фоновой текстуры
    local bgPath = configPath .. "background.jpg"
    if doesFileExist(bgPath) then
        bgTexture = imgui.CreateTextureFromFile(bgPath)
        if bgTexture then
            bgLoaded = true
        end
    end
    
    local style = imgui.GetStyle()
    
    style.WindowRounding = 8
    style.ChildRounding = 6
    style.FrameRounding = 4
    style.PopupRounding = 4
    style.ScrollbarRounding = 4
    style.GrabRounding = 4
    style.TabRounding = 4
    
    style.WindowPadding = imgui.ImVec2(0, 0)
    style.FramePadding = imgui.ImVec2(8, 6)
    style.ItemSpacing = imgui.ImVec2(8, 6)
    style.ItemInnerSpacing = imgui.ImVec2(6, 6)
    style.ScrollbarSize = 12
    style.GrabMinSize = 10
    
    style.WindowBorderSize = 0
    style.ChildBorderSize = 0
    style.PopupBorderSize = 0
    style.FrameBorderSize = 0
    
    local c = style.Colors
    c[imgui.Col.WindowBg] = colors.content
    c[imgui.Col.ChildBg] = imgui.ImVec4(0, 0, 0, 0)
    c[imgui.Col.PopupBg] = colors.header
    c[imgui.Col.Border] = colors.border
    c[imgui.Col.FrameBg] = colors.sidebarItem
    c[imgui.Col.FrameBgHovered] = colors.sidebarHover
    c[imgui.Col.FrameBgActive] = colors.accent
    c[imgui.Col.TitleBg] = colors.sidebar
    c[imgui.Col.TitleBgActive] = colors.sidebar
    c[imgui.Col.MenuBarBg] = colors.sidebar
    c[imgui.Col.ScrollbarBg] = colors.sidebar
    c[imgui.Col.ScrollbarGrab] = colors.sidebarHover
    c[imgui.Col.ScrollbarGrabHovered] = colors.accent
    c[imgui.Col.ScrollbarGrabActive] = colors.accentHover
    c[imgui.Col.CheckMark] = colors.accent
    c[imgui.Col.SliderGrab] = colors.accent
    c[imgui.Col.SliderGrabActive] = colors.accentHover
    c[imgui.Col.Button] = colors.sidebarItem
    c[imgui.Col.ButtonHovered] = colors.sidebarHover
    c[imgui.Col.ButtonActive] = colors.accent
    c[imgui.Col.Header] = colors.sidebarItem
    c[imgui.Col.HeaderHovered] = colors.sidebarHover
    c[imgui.Col.HeaderActive] = colors.accent
    c[imgui.Col.Separator] = colors.border
    c[imgui.Col.Text] = colors.text
    c[imgui.Col.TextDisabled] = colors.textDark
    c[imgui.Col.Tab] = colors.sidebarItem
    c[imgui.Col.TabHovered] = colors.accent
    c[imgui.Col.TabActive] = colors.accent
    c[imgui.Col.TabUnfocused] = colors.sidebarItem
    c[imgui.Col.TabUnfocusedActive] = colors.sidebarHover
    
    initToggles()
    loadConfig()
end)

-- Главное окно
local mainFrame = imgui.OnFrame(
    function() return mainWindow[0] end,
    function(player)
        player.HideCursor = false
        
        local windowWidth = 900
        local windowHeight = 580
        local sidebarWidth = 200
        
        imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.FirstUseEver)
        
        imgui.Begin("##government_helper", mainWindow, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize)
        
        -- Фоновое изображение
        if bgLoaded and bgTexture then
            local pos = imgui.GetWindowPos()
            imgui.GetWindowDrawList():AddImage(bgTexture, pos, imgui.ImVec2(pos.x + windowWidth, pos.y + windowHeight), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), 0x80FFFFFF)
        end
        
        -- SIDEBAR
        imgui.PushStyleColor(imgui.Col.ChildBg, colors.sidebar)
        imgui.BeginChild("##sidebar", imgui.ImVec2(sidebarWidth, -1), false)
        
        -- Логотип
        imgui.SetCursorPos(imgui.ImVec2(0, 20))
        local logoSize = 80
        imgui.SetCursorPosX((sidebarWidth - logoSize) / 2)
        
        if logoLoaded and logoTexture then
            imgui.Image(logoTexture, imgui.ImVec2(logoSize, logoSize))
        else
            imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.29, 0.56, 0.85, 0.2))
            imgui.BeginChild("##logo_fallback", imgui.ImVec2(logoSize, logoSize), false)
            imgui.SetCursorPos(imgui.ImVec2(20, 25))
            imgui.TextColored(colors.accent, "GOV")
            imgui.EndChild()
            imgui.PopStyleColor()
        end
        
        -- Заголовок
        imgui.SetCursorPosY(115)
        local title = "GOVERNMENT"
        local titleWidth = imgui.CalcTextSize(title).x
        imgui.SetCursorPosX((sidebarWidth - titleWidth) / 2)
        imgui.TextColored(colors.accent, title)
        
        local subtitle = "HELPER"
        local subtitleWidth = imgui.CalcTextSize(subtitle).x
        imgui.SetCursorPosX((sidebarWidth - subtitleWidth) / 2)
        imgui.TextColored(colors.textDark, subtitle)
        
        imgui.SetCursorPosY(160)
        imgui.Separator()
        
        -- Навигация
        imgui.SetCursorPosY(175)
        for i, item in ipairs(menuItems) do
            local isSelected = (currentTab == i)
            
            if isSelected then
                imgui.PushStyleColor(imgui.Col.Button, colors.accent)
                imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.accentHover)
                imgui.PushStyleColor(imgui.Col.ButtonActive, colors.accentHover)
            else
                imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0, 0, 0, 0))
                imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.sidebarHover)
                imgui.PushStyleColor(imgui.Col.ButtonActive, colors.accent)
            end
            
            imgui.SetCursorPosX(10)
            if imgui.Button("    " .. item.nameRu .. "##nav" .. i, imgui.ImVec2(sidebarWidth - 20, 32)) then
                currentTab = i
            end
            imgui.PopStyleColor(3)
        end
        
        imgui.EndChild()
        imgui.PopStyleColor()
        
        imgui.SameLine(0, 0)
        
        -- КОНТЕНТ
        imgui.BeginChild("##content", imgui.ImVec2(-1, -1), false)
        
        -- Заголовок
        imgui.PushStyleColor(imgui.Col.ChildBg, colors.header)
        imgui.BeginChild("##header", imgui.ImVec2(-1, 45), false)
        imgui.SetCursorPos(imgui.ImVec2(15, 12))
        imgui.TextColored(colors.text, "<<  " .. menuItems[currentTab].nameRu .. "  >>")
        
        -- Кнопка закрытия
        imgui.SetCursorPos(imgui.ImVec2(windowWidth - sidebarWidth - 40, 8))
        imgui.PushStyleColor(imgui.Col.Button, colors.red)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.95, 0.4, 0.4, 1.0))
        if imgui.Button("X##close", imgui.ImVec2(28, 28)) then
            mainWindow[0] = false
        end
        imgui.PopStyleColor(2)
        imgui.EndChild()
        imgui.PopStyleColor()
        
        -- Тело контента
        imgui.BeginChild("##body", imgui.ImVec2(-1, -1), false)
        imgui.SetCursorPos(imgui.ImVec2(15, 15))
        
        -- Вкладки
        if currentTab == 1 then
            -- Главная с информацией об организации
            imgui.TextColored(colors.green, "Добро пожаловать в Government Helper!")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            -- Информация о сотруднике
            imgui.PushStyleColor(imgui.Col.ChildBg, colors.sidebarItem)
            imgui.BeginChild("##info_panel", imgui.ImVec2(-30, 180), false)
            imgui.SetCursorPos(imgui.ImVec2(15, 15))
            imgui.TextColored(colors.accent, "Информация о сотруднике:")
            imgui.SetCursorPos(imgui.ImVec2(15, 40))
            local _, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
            imgui.Text("Ваш ID: " .. (myId or "N/A"))
            imgui.SetCursorPos(imgui.ImVec2(15, 58))
            imgui.Text("Имя: " .. (playerInfo.name ~= "" and playerInfo.name or "Неизвестно"))
            imgui.SetCursorPos(imgui.ImVec2(15, 76))
            imgui.Text("Пол: " .. playerInfo.sex)
            imgui.SetCursorPos(imgui.ImVec2(15, 94))
            imgui.Text("Организация: " .. playerInfo.organization)
            imgui.SetCursorPos(imgui.ImVec2(15, 112))
            imgui.Text("Должность: " .. playerInfo.rank .. " (" .. playerInfo.rankNumber .. ")")
            imgui.SetCursorPos(imgui.ImVec2(15, 135))
            imgui.PushStyleColor(imgui.Col.Button, colors.accent)
            if imgui.Button("Обновить данные##refresh", imgui.ImVec2(150, 28)) then
                checkStats = true
                sampSendChat("/stats")
            end
            imgui.PopStyleColor()
            imgui.EndChild()
            imgui.PopStyleColor()
            
            imgui.Spacing()
            imgui.Spacing()
            
            -- Ближайший игрок
            imgui.PushStyleColor(imgui.Col.ChildBg, colors.sidebarItem)
            imgui.BeginChild("##closest_panel", imgui.ImVec2(-30, 60), false)
            imgui.SetCursorPos(imgui.ImVec2(15, 15))
            local closestId = get_closest_player_id()
            if closestId >= 0 then
                imgui.TextColored(colors.orange, "Ближайший игрок:")
                imgui.SameLine()
                imgui.Text(sampGetPlayerNickname(closestId) .. " [" .. closestId .. "]")
            else
                imgui.TextColored(colors.textDark, "Ближайший игрок: Не найден")
            end
            imgui.EndChild()
            imgui.PopStyleColor()
            
            imgui.Spacing()
            imgui.Spacing()
            
            imgui.PushStyleColor(imgui.Col.ChildBg, colors.sidebarItem)
            imgui.BeginChild("##hotkeys_info", imgui.ImVec2(-30, 60), false)
            imgui.SetCursorPos(imgui.ImVec2(15, 15))
            imgui.TextColored(colors.gold, "Горячие клавиши:")
            imgui.SetCursorPos(imgui.ImVec2(15, 35))
            imgui.Text("F2 или /gh - Меню  |  F6 или /gm - Быстрое меню")
            imgui.EndChild()
            imgui.PopStyleColor()
            
        elseif currentTab == 2 then
            -- Команды
            imgui.TextColored(colors.accent, "Список команд:")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            local commands = {
                {"/gh", "Открыть главное меню"},
                {"/gm", "Открыть быстрое меню"},
                {"/ghello", "Приветствие"},
                {"/gbye", "Прощание"},
                {"/gdoc", "Запросить документы"},
                {"/gpass", "Выдать паспорт"},
                {"/gmedcard", "Выдать медкарту"},
                {"/glicense", "Выдать лицензию"},
                {"/ghire1", "Начало собеседования"},
                {"/ghire3", "Принятие на работу"},
                {"/gmar1", "Начало регистрации брака"},
                {"/gdiv1", "Начало оформления развода"},
                {"/gshowpass", "Показать свой паспорт"},
                {"/gshowlic", "Показать свои лицензии"}
            }
            
            for _, cmd in ipairs(commands) do
                imgui.TextColored(colors.green, cmd[1])
                imgui.SameLine()
                imgui.TextColored(colors.textDark, " - " .. cmd[2])
            end
            
        elseif currentTab == 3 then
            -- Отыгровки
            imgui.TextColored(colors.accent, "Отыгровки:")
            imgui.Spacing()
            
            imgui.BeginChild("##categories_list", imgui.ImVec2(200, -50), true)
            imgui.TextColored(colors.textDark, "Категории:")
            imgui.Separator()
            for i, cat in ipairs(categories) do
                if imgui.Selectable(cat.nameRu .. "##cat" .. i, selectedCategory[0] == i - 1) then
                    selectedCategory[0] = i - 1
                    selectedBind[0] = 0
                end
            end
            imgui.EndChild()
            
            imgui.SameLine()
            
            imgui.BeginChild("##binds_list", imgui.ImVec2(-15, -50), true)
            imgui.TextColored(colors.textDark, "Бинды:")
            imgui.Separator()
            
            local catData = categories[selectedCategory[0] + 1]
            if catData then
                local catBinds = binds[catData.data]
                if catBinds then
                    for i, bind in ipairs(catBinds) do
                        if bindToggles[catData.data] and bindToggles[catData.data][i] then
                            if imgui.Checkbox("##toggle" .. catData.data .. i, bindToggles[catData.data][i]) then
                                bind.enabled = bindToggles[catData.data][i][0]
                            end
                            imgui.SameLine()
                        end
                        
                        if imgui.Selectable(bind.descRu .. "##bind" .. i, selectedBind[0] == i - 1, 0, imgui.ImVec2(200, 0)) then
                            selectedBind[0] = i - 1
                        end
                        
                        imgui.SameLine()
                        
                        local keyName = getHotkeyName(bind.hotkey)
                        local btnLabel = (waitingForKey and waitingBindCat == catData.data and waitingBindIdx == i) and "..." or keyName
                        
                        imgui.PushStyleColor(imgui.Col.Button, colors.sidebarHover)
                        if imgui.Button(btnLabel .. "##hk" .. catData.data .. i, imgui.ImVec2(60, 0)) then
                            waitingForKey = true
                            waitingBindCat = catData.data
                            waitingBindIdx = i
                        end
                        imgui.PopStyleColor()
                        
                        if bind.hotkey.key ~= 0 then
                            imgui.SameLine()
                            imgui.PushStyleColor(imgui.Col.Button, colors.red)
                            if imgui.Button("X##reset" .. catData.data .. i, imgui.ImVec2(20, 0)) then
                                bind.hotkey = {key = 0, ctrl = false, shift = false, alt = false}
                            end
                            imgui.PopStyleColor()
                        end
                    end
                end
            end
            imgui.EndChild()
            
            imgui.PushStyleColor(imgui.Col.Button, colors.accent)
            if imgui.Button("Выполнить##execute", imgui.ImVec2(150, 35)) then
                local catData = categories[selectedCategory[0] + 1]
                if catData then
                    local catBinds = binds[catData.data]
                    if catBinds and catBinds[selectedBind[0] + 1] then
                        local bind = catBinds[selectedBind[0] + 1]
                        if bind.enabled then
                            sendBind(bind.lines, bind.stat)
                            mainWindow[0] = false
                        end
                    end
                end
            end
            imgui.PopStyleColor()
            
        elseif currentTab == 4 then
            -- Мои документы - ПОКАЗ своих документов
            imgui.TextColored(colors.accent, "Показать свои документы:")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            -- Добавлено поле ввода ID игрока
            imgui.TextColored(colors.textDark, "ID игрока которому показываем документы:")
            imgui.Spacing()
            imgui.PushItemWidth(150)
            imgui.InputText("##target_id", myDocsTargetId, sizeof(myDocsTargetId))
            imgui.PopItemWidth()
            imgui.SameLine()
            imgui.PushStyleColor(imgui.Col.Button, colors.accent)
            if imgui.Button("Ближайший##closest", imgui.ImVec2(100, 0)) then
                local closest = get_closest_player_id()
                if closest >= 0 then
                    ffi.copy(myDocsTargetId, tostring(closest))
                end
            end
            imgui.PopStyleColor()
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            imgui.TextColored(colors.textDark, "Отыгровки для показа ваших документов:")
            imgui.Spacing()
            
            for i, bind in ipairs(myDocsBinds) do
                imgui.PushStyleColor(imgui.Col.Button, colors.sidebarItem)
                imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.accent)
                if imgui.Button(bind.name .. "##mydoc" .. i, imgui.ImVec2(200, 0)) then
                    local nearestPlayerId = get_closest_player_id() -- Переменная для nearestPlayerId
                    -- Исправлена обработка lines - используем прямое добавление без table.insert
                    local linesToSend = {}
                    local bindLines = bind.lines
                    
                    if type(bindLines) == "string" then
                        linesToSend[#linesToSend + 1] = bindLines:gsub("{id}", ffi.string(myDocsTargetId) == "" and tostring(nearestPlayerId or 0) or ffi.string(myDocsTargetId))
                    elseif type(bindLines) == "table" then
                        for j = 1, #bindLines do
                            local line = bindLines[j]
                            if type(line) == "string" then
                                linesToSend[#linesToSend + 1] = line:gsub("{id}", ffi.string(myDocsTargetId) == "" and tostring(nearestPlayerId or 0) or ffi.string(myDocsTargetId))
                            end
                        end
                    end
                    
                    if #linesToSend > 0 then
                        sendBind(linesToSend)
                    end
                    mainWindow[0] = false
                end
                imgui.PopStyleColor(2)

                imgui.SameLine()
                
                -- Горячая клавиша для каждого бинда
                local keyName = getHotkeyName(bind.hotkey)
                local btnLabel = (waitingForKey == "mydocs" and waitingBindIdx == i) and "..." or keyName -- Исправлено условие
                
                imgui.PushStyleColor(imgui.Col.Button, colors.sidebarHover)
                if imgui.Button(btnLabel .. "##hkmydoc" .. i, imgui.ImVec2(60, 0)) then
                    waitingForKey = "mydocs" -- Отмечаем, что ожидание для "mydocs"
                    waitingBindIdx = i
                end
                imgui.PopStyleColor()
                
                if bind.hotkey.key ~= 0 then
                    imgui.SameLine()
                    imgui.PushStyleColor(imgui.Col.Button, colors.red)
                    if imgui.Button("X##resetmydoc" .. i, imgui.ImVec2(20, 0)) then
                        bind.hotkey = {key = 0, ctrl = false, shift = false, alt = false}
                    end
                    imgui.PopStyleColor()
                end
            end
            
        elseif currentTab == 5 then
            -- Собрания
            imgui.TextColored(colors.accent, "Отыгровки для собраний:")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            local meetingBinds = {
                {name = "Начало собрания", lines = {
                    "/me включил микрофон",
                    "/do Микрофон включен.",
                    "Внимание! Начинается собрание Правительства."
                }},
                {name = "Завершение собрания", lines = {
                    "На этом собрание окончено.",
                    "Всем спасибо за внимание!",
                    "/me выключил микрофон"
                }},
                {name = "Призыв к тишине", lines = {
                    "Прошу соблюдать тишину!",
                    "Дождитесь своей очереди для вопросов."
                }},
                {name = "Слово участнику", lines = {
                    "Сейчас слово предоставляется...",
                    "Прошу всех выслушать."
                }},
                {name = "Объявление", lines = {
                    "/me взял лист с объявлением",
                    "Внимание, важное объявление!"
                }}
            }
            
            for i, mb in ipairs(meetingBinds) do
                imgui.PushStyleColor(imgui.Col.Button, colors.sidebarItem)
                imgui.PushStyleColor(imgui.Col.ButtonHovered, colors.accent)
                if imgui.Button(mb.name .. "##meet" .. i, imgui.ImVec2(-30, 35)) then
                    sendBind(mb.lines)
                    mainWindow[0] = false
                end
                imgui.PopStyleColor(2)
            end
            
        elseif currentTab == 6 then
            -- Устав
            imgui.TextColored(colors.accent, "Устав Правительства штата Спэйс:")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            -- Список глав
            imgui.BeginChild("##ustav_chapters", imgui.ImVec2(250, -30), true)
            imgui.TextColored(colors.textDark, "Главы:")
            imgui.Separator()
            for i, chapter in ipairs(ustavChapters) do
                if imgui.Selectable(chapter.title .. "##ust" .. i, selectedUstavChapter[0] == i - 1) then
                    selectedUstavChapter[0] = i - 1
                end
            end
            imgui.EndChild()
            
            imgui.SameLine()
            
            -- Содержимое главы
            imgui.BeginChild("##ustav_content", imgui.ImVec2(-15, -30), true)
            local chapter = ustavChapters[selectedUstavChapter[0] + 1]
            if chapter then
                imgui.TextColored(colors.gold, chapter.title)
                imgui.Separator()
                imgui.Spacing()
                for _, line in ipairs(chapter.content) do
                    imgui.TextWrapped(line)
                end
            end
            imgui.EndChild()
            
        elseif currentTab == 7 then
            -- Статистика
            imgui.TextColored(colors.accent, "Ваша статистика:")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            imgui.PushStyleColor(imgui.Col.ChildBg, colors.sidebarItem)
            imgui.BeginChild("##stats_panel", imgui.ImVec2(-30, 280), false)
            imgui.SetCursorPos(imgui.ImVec2(15, 15))
            
            local stats = {
                {"Запрошено документов", statistics.documents, colors.accent},
                {"Выдано паспортов", statistics.passports, colors.green},
                {"Выдано медкарт", statistics.medcards, colors.green},
                {"Выдано лицензий", statistics.licenses, colors.green},
                {"Проведено собеседований", statistics.interviews, colors.orange},
                {"Принято сотрудников", statistics.hired, colors.green},
                {"Уволено сотрудников", statistics.fired, colors.red},
                {"Зарегистрировано браков", statistics.marriages, colors.purple},
                {"Оформлено разводов", statistics.divorces, colors.textDark},
                {"Выписано штрафов", statistics.fines, colors.red}
            }
            
            local y = 15
            for _, stat in ipairs(stats) do
                imgui.SetCursorPos(imgui.ImVec2(15, y))
                imgui.TextColored(stat[3], stat[1] .. ":")
                imgui.SameLine()
                imgui.Text(tostring(stat[2]))
                y = y + 24
            end
            
            imgui.EndChild()
            imgui.PopStyleColor()
            
            imgui.Spacing()
            imgui.PushStyleColor(imgui.Col.Button, colors.red)
            if imgui.Button("Сбросить статистику##reset_stats", imgui.ImVec2(200, 30)) then
                for k in pairs(statistics) do
                    statistics[k] = 0
                end
                saveConfig()
            end
            imgui.PopStyleColor()
            
        elseif currentTab == 8 then
            -- Заметки
            imgui.TextColored(colors.accent, "Ваши заметки:")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            imgui.BeginChild("##notes_list", imgui.ImVec2(-30, 200), true)
            for i, note in ipairs(notes) do
                local shortNote = note:sub(1, 50) .. (note:len() > 50 and "..." or "")
                if imgui.Selectable(i .. ". " .. shortNote .. "##note" .. i, selectedNote[0] == i - 1) then
                    selectedNote[0] = i - 1
                    ffi.copy(noteInput, note)
                end
            end
            imgui.EndChild()
            
            imgui.Spacing()
            imgui.InputTextMultiline("##note_input", noteInput, sizeof(noteInput), imgui.ImVec2(-30, 80))
            imgui.Spacing()
            
            imgui.PushStyleColor(imgui.Col.Button, colors.green)
            if imgui.Button("Добавить##add_note", imgui.ImVec2(100, 30)) then
                local text = str(noteInput)
                if text ~= "" then
                    table.insert(notes, text)
                    ffi.fill(noteInput, sizeof(noteInput))
                    saveConfig()
                end
            end
            imgui.PopStyleColor()
            
            imgui.SameLine()
            
            imgui.PushStyleColor(imgui.Col.Button, colors.orange)
            if imgui.Button("Обновить##update_note", imgui.ImVec2(100, 30)) then
                local text = str(noteInput)
                if text ~= "" and notes[selectedNote[0] + 1] then
                    notes[selectedNote[0] + 1] = text
                    saveConfig()
                end
            end
            imgui.PopStyleColor()
            
            imgui.SameLine()
            
            imgui.PushStyleColor(imgui.Col.Button, colors.red)
            if imgui.Button("Удалить##delete_note", imgui.ImVec2(100, 30)) then
                if notes[selectedNote[0] + 1] then
                    table.remove(notes, selectedNote[0] + 1)
                    ffi.fill(noteInput, sizeof(noteInput))
                    selectedNote[0] = 0
                    saveConfig()
                end
            end
            imgui.PopStyleColor()
            
        elseif currentTab == 9 then
            -- Настройки
            imgui.TextColored(colors.accent, "Настройки:")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            imgui.PushStyleColor(imgui.Col.ChildBg, colors.sidebarItem)
            imgui.BeginChild("##settings_panel", imgui.ImVec2(-30, 200), false)
            imgui.SetCursorPos(imgui.ImVec2(15, 15))
            
            imgui.TextColored(colors.textDark, "Задержка между сообщениями (мс):")
            imgui.SetCursorPos(imgui.ImVec2(15, 40))
            local delayInput = new.int(settings.delay)
            imgui.PushItemWidth(200)
            -- Увеличен диапазон слайдера с 500-3000 до 1000-5000 мс
            if imgui.SliderInt("##delay", delayInput, 1000, 5000) then
                settings.delay = delayInput[0]
                saveConfig()
            end
            imgui.PopItemWidth()
            
            imgui.SetCursorPos(imgui.ImVec2(15, 80))
            imgui.TextColored(colors.textDark, "Пол персонажа:")
            imgui.SetCursorPos(imgui.ImVec2(15, 105))
            
            if imgui.Button(settings.sex == 1 and "[X] Мужской" or "[ ] Мужской", imgui.ImVec2(120, 30)) then
                settings.sex = 1
                saveConfig()
            end
            imgui.SameLine()
            if imgui.Button(settings.sex == 2 and "[X] Женский" or "[ ] Женский", imgui.ImVec2(120, 30)) then
                settings.sex = 2
                saveConfig()
            end
            
            imgui.SetCursorPos(imgui.ImVec2(15, 150))
            imgui.PushStyleColor(imgui.Col.Button, colors.accent)
            if imgui.Button("Обновить данные из /stats", imgui.ImVec2(200, 30)) then
                checkStats = true
                sampSendChat("/stats")
            end
            imgui.PopStyleColor()
            
            imgui.EndChild()
            imgui.PopStyleColor()
            
        elseif currentTab == 10 then
            -- О скрипте
            imgui.TextColored(colors.accent, "О скрипте:")
            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()
            
            imgui.PushStyleColor(imgui.Col.ChildBg, colors.sidebarItem)
            imgui.BeginChild("##about_panel", imgui.ImVec2(-30, 200), false)
            imgui.SetCursorPos(imgui.ImVec2(15, 15))
            imgui.TextColored(colors.gold, "Government Helper v25.1")
            imgui.SetCursorPos(imgui.ImVec2(15, 40))
            imgui.Text("Биндер для Правительства Arizona RP")
            imgui.SetCursorPos(imgui.ImVec2(15, 65))
            imgui.TextColored(colors.textDark, "Автор: v0")
            imgui.SetCursorPos(imgui.ImVec2(15, 90))
            imgui.Text("Возможности:")
            imgui.SetCursorPos(imgui.ImVec2(15, 110))
            imgui.TextColored(colors.textDark, "- Отыгровки для всех ситуаций")
            imgui.SetCursorPos(imgui.ImVec2(15, 128))
            imgui.TextColored(colors.textDark, "- Горячие клавиши")
            imgui.SetCursorPos(imgui.ImVec2(15, 146))
            imgui.TextColored(colors.textDark, "- Статистика работы")
            imgui.SetCursorPos(imgui.ImVec2(15, 164))
            imgui.TextColored(colors.textDark, "- Личные заметки")
            imgui.EndChild()
            imgui.PopStyleColor()
        end
        
        imgui.EndChild()
        imgui.EndChild()
        imgui.End()
    end
)

-- Быстрое меню
local quickFrame = imgui.OnFrame(
  function() return quickWindow[0] end,
  function(player)
    player.HideCursor = false
    
    imgui.SetNextWindowPos(imgui.ImVec2(sizeX / 2, sizeY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(300, 400), imgui.Cond.FirstUseEver)
    
    imgui.Begin("Быстрое меню##quick", quickWindow, imgui.WindowFlags.NoResize)
    
    local quickBinds = {
      {name = "Приветствие", cat = "greeting", idx = 1},
      {name = "Прощание", cat = "greeting", idx = 2},
      {name = "Запросить документы", cat = "docs", idx = 1},
      {name = "Вернуть документы", cat = "docs", idx = 2},
      {name = "Выдать паспорт", cat = "docs", idx = 3},
      {name = "Выдать медкарту", cat = "docs", idx = 4},
      {name = "Начало собеседования", cat = "hire", idx = 1},
      {name = "Принятие на работу", cat = "hire", idx = 3},
      {name = "Показать паспорт", special = "mydocs", idx = 1},
      {name = "Показать все документы", special = "mydocs", idx = 5}
    }
    
    for _, qb in ipairs(quickBinds) do
      if imgui.Button(qb.name .. "##qb", imgui.ImVec2(-1, 30)) then
        if qb.special == "mydocs" then
          local nearestPlayerId = get_closest_player_id() -- Переменная для nearestPlayerId
          -- Исправлена обработка lines - используем прямое добавление без table.insert
          local linesToSend = {}
          local bindLines = myDocsBinds[qb.idx].lines
          
          if type(bindLines) == "string" then
              linesToSend[#linesToSend + 1] = bindLines:gsub("{id}", ffi.string(myDocsTargetId) == "" and tostring(nearestPlayerId or 0) or ffi.string(myDocsTargetId))
          elseif type(bindLines) == "table" then
              for j = 1, #bindLines do
                  local line = bindLines[j]
                  if type(line) == "string" then
                      linesToSend[#linesToSend + 1] = line:gsub("{id}", ffi.string(myDocsTargetId) == "" and tostring(nearestPlayerId or 0) or ffi.string(myDocsTargetId))
                  end
              end
          end
          
          if #linesToSend > 0 then
            sendBind(linesToSend)
          end
        else
          local bind = binds[qb.cat][qb.idx]
          if bind and bind.enabled then
            sendBind(bind.lines, bind.stat)
          end
        end
        quickWindow[0] = false
      end
    end
    
    imgui.End()
  end
)

-- Функция проверки обновлений
function checkForUpdates()
    local tempPath = os.getenv("TEMP") .. "\\gh_version.txt"
    
    downloadUrlToFile(VERSION_URL, tempPath, function(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            local file = io.open(tempPath, "r")
            if file then
                latestVersion = file:read("*l")
                file:close()
                os.remove(tempPath)
                
                if latestVersion and latestVersion ~= SCRIPT_VERSION then
                    updateAvailable = true
                    sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {00FF00}Доступна новая версия: " .. latestVersion), -1)
                    sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {FFFFFF}Введите /gdownload для обновления"), -1)
                    
                    -- Регистрируем команду скачивания только если есть обновление
                    sampRegisterChatCommand("gdownload", downloadUpdate)
                else
                    sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {00FF00}У вас актуальная версия: " .. SCRIPT_VERSION), -1)
                end
            end
        elseif status == dlstatus.STATUS_DOWNLOADINGDATA then
            -- Скачивание в процессе
        end
    end)
end

-- Функция скачивания обновления
function downloadUpdate()
    if not updateAvailable then
        sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {FFFFFF}Обновлений не найдено."), -1)
        return
    end
    
    sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {FFFFFF}Скачивание обновления..."), -1)
    
    downloadUrlToFile(UPDATE_URL, SCRIPT_PATH, function(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {00FF00}Обновление скачано! Перезагрузка скрипта..."), -1)
            wait(1000)
            thisScript():reload()
        elseif status == dlstatus.STATUS_DOWNLOADINGDATA then
            -- Показываем прогресс
            local percent = math.floor(p1 / p2 * 100)
            -- sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {FFFFFF}Скачивание: " .. percent .. "%"), -1)
        end
    end)
end

-- Основной цикл
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    
    -- Создание папки для настроек
    if not doesDirectoryExist(configPath) then
        createDirectory(configPath)
    end
    
    loadConfig()
    initToggles()
    
    -- Используем toCP1251 для сообщений в чат
    sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {FFFFFF}Скрипт загружен. Версия: " .. SCRIPT_VERSION), -1)
    sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {FFFFFF}/gh - меню, /gm - быстрое меню, /gupdate - обновление"), -1)
    
    -- Проверка обновлений при запуске
    lua_thread.create(checkForUpdates)
    
    -- Регистрация команд
    sampRegisterChatCommand("gh", function() mainWindow[0] = not mainWindow[0] end)
    sampRegisterChatCommand("gm", function() quickWindow[0] = not quickWindow[0] end)
    sampRegisterChatCommand("stop", function()
        stopBind = true
        isBindPlaying = false
        sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {FF0000}Отыгровка остановлена."), -1)
    end)
    sampRegisterChatCommand("gstats", function() 
        sampSendChat("/stats")
        sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {FFFFFF}Обновление данных..."), -1)
    end)
    
    -- Добавлена команда для ручной проверки обновлений
    sampRegisterChatCommand("gupdate", function()
        sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {FFFFFF}Проверка обновлений..."), -1)
        lua_thread.create(checkForUpdates)
    end)
    
    -- Регистрация команд биндов
    for catName, catBinds in pairs(binds) do
        for _, bind in ipairs(catBinds) do
            sampRegisterChatCommand(bind.cmd, function()
                sendBind(bind.lines, bind.stat)
            end)
        end
    end
    
    -- Регистрация команд для "Мои документы"
    for _, bind in ipairs(myDocsBinds) do
        sampRegisterChatCommand(bind.cmd, function(arg)
            local targetId = tonumber(arg) or get_closest_player_id()
            if targetId >= 0 then
                local lines = {}
                for _, line in ipairs(bind.lines) do
                    table.insert(lines, line:gsub("{id}", targetId))
                end
                sendBind(lines)
            else
                sampAddChatMessage(toCP1251("{4A90D9}[Government Helper] {FF0000}Игрок не найден!"), -1)
            end
        end)
    end
    
    while true do
        wait(0)
        
        -- Горячие клавиши для меню
        if not sampIsChatInputActive() and not sampIsDialogActive() then
            if isKeyJustPressed(vkeys.VK_F2) then
                mainWindow[0] = not mainWindow[0]
            end
            if isKeyJustPressed(vkeys.VK_F6) then
                quickWindow[0] = not quickWindow[0]
            end
            
            -- Обработка горячих клавиш биндов
            for catName, catBinds in pairs(binds) do
                for i, bind in ipairs(catBinds) do
                    if isHotkeyPressed(bind.hotkey) then
                        if bindToggles[catName] and bindToggles[catName][i] and bindToggles[catName][i][0] then
                            sendBind(bind.lines, bind.stat)
                        end
                    end
                end
            end
            
            -- Горячие клавиши для "Мои документы"
            for _, bind in ipairs(myDocsBinds) do
                if isHotkeyPressed(bind.hotkey) then
                    local targetId = tonumber(str(myDocsTargetId)) or get_closest_player_id()
                    if targetId >= 0 then
                        local lines = {}
                        for _, line in ipairs(bind.lines) do
                            table.insert(lines, (line:gsub("{id}", targetId)))
                        end
                        sendBind(lines)
                    end
                end
            end
            
            -- Ожидание нажатия клавиши для привязки
            if waitingForKey then
                for key, name in pairs(keyNames) do
                    if key > 0 and isKeyJustPressed(key) then
                        if waitingForKey == "mydocs" and waitingBindIdx then
                            myDocsBinds[waitingBindIdx].hotkey = {key = key, ctrl = isKeyDown(vkeys.VK_CONTROL), shift = isKeyDown(vkeys.VK_SHIFT), alt = isKeyDown(vkeys.VK_MENU)}
                        elseif waitingBindCat and waitingBindIdx then
                            binds[waitingBindCat][waitingBindIdx].hotkey = {key = key, ctrl = isKeyDown(vkeys.VK_CONTROL), shift = isKeyDown(vkeys.VK_SHIFT), alt = isKeyDown(vkeys.VK_MENU)}
                        end
                        waitingForKey = nil
                        waitingBindCat = nil
                        waitingBindIdx = nil
                        saveConfig()
                        break
                    end
                end
                -- ESC для отмены
                if isKeyJustPressed(vkeys.VK_ESCAPE) then
                    waitingForKey = nil
                    waitingBindCat = nil
                    waitingBindIdx = nil
                end
            end
        end
    end
end
