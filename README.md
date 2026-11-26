# THE NEST

Хоррор для Роблокса. Один из вас монстр. Каждый, кого он убьёт, станет новым.
Найдите коконы, пока они не вылупились, и включите свет.

## Что где лежит

- `src/server/` — скрипты на сервере (раунды, монстр, коконы) → ServerScriptService
- `src/client/` — скрипты у игрока (экран, фонарик) → StarterPlayerScripts
- `src/shared/` — общие модули и настройки (`Config.luau`) → ReplicatedStorage

Карта (стены, комнаты, тайники) строится прямо в Studio, в Git её нет.

## Первый запуск (каждый)

1. Установите Git, VS Code (+ расширение Luau LSP) и Rokit.
2. `git clone <ссылка на репозиторий>`
3. `cd the-nest`
4. `rokit install`
5. `rojo plugin install` (ставит плагин Rojo в Studio)

## Каждый день

1. `git pull`
2. `rojo serve`
3. В Studio откройте игру → плагин Rojo → Connect
4. Пишите код в VS Code
5. `git add .` → `git commit -m "что сделал"` → `git push`

## Для теста

В Workspace поставьте две детали: `MonsterSpawn` и `SurvivorSpawn`.
Для теста вдвоём в Studio: Test → Clients and Servers → 2 Players.
