ESX = exports['es_extended']:getSharedObject()

RegisterCommand('billingmenu', function()
    ESX.TriggerServerCallback('billing:isAdmin', function(isAdmin)
        local elements = {
            {label = '📜 Meine Rechnungen', value = 'my_bills'},
            {label = '📝 Rechnung erstellen', value = 'create_bill'}
        }

        if isAdmin then
            table.insert(elements, {label = '🔎 Alle Rechnungen (Admin)', value = 'all_bills'})
        end

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'billing_main', {
            title = 'Rechnungsmenü',
            align = 'top-left',
            css   = 'rechnung',
            elements = elements
        }, function(data, menu)
            if data.current.value == 'my_bills' then
                ShowMyBills()
            elseif data.current.value == 'create_bill' then
                CreateBill()
            elseif data.current.value == 'all_bills' then
                ShowAllBills()
            end
        end, function(data, menu)
            menu.close()
        end)
    end)
end)

function ShowMyBills()
    ESX.TriggerServerCallback('billing:getBills', function(bills)
        local elements = {}
        for _, bill in pairs(bills) do
            table.insert(elements, {
                label = ('%s - <span style="color:red;">$%s</span>'):format(bill.label, ESX.Math.GroupDigits(bill.amount)),
                value = bill.id
            })
        end

        if #bills > 0 then
            -- table.insert(elements, {label = '💳 Alle Rechnungen bezahlen', value = 'pay_all'})
        end

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'my_bills', {
            title = 'Meine Rechnungen',
            align = 'top-left',
            css   = 'rechnung',
            elements = elements
        }, function(data, menu)
            if data.current.value == 'pay_all' then
                TriggerServerEvent('esx:payAllBills')
                menu.close()
            else
                TriggerServerEvent('billing:payBill', data.current.value)
                menu.close()
            end
        end, function(data, menu)
            menu.close()
        end)
    end)
end

function CreateBill()
    local playerList = ESX.Game.GetPlayersInArea(GetEntityCoords(PlayerPedId()), 3.0)
    local elements = {}
    for i=1, #playerList do
        local target = GetPlayerServerId(playerList[i])
        table.insert(elements, {
            label = ('Spieler %s'):format(target),
            value = target
        })
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'select_player', {
        title = 'Spieler auswählen',
        align = 'top-left',
        css   = 'rechnung',
        elements = elements
    }, function(data, menu)
        local targetId = data.current.value
        ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'bill_label', {
            title = 'Grund der Rechnung'
        }, function(data2, menu2)
            local label = data2.value
            ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'bill_amount', {
                title = 'Betrag in $'
            }, function(data3, menu3)
                local amount = tonumber(data3.value)
                if amount == nil or amount <= 0 then return end

                TriggerServerEvent('billing:createBill', targetId, label, amount)
                ESX.ShowNotification('Rechnung gesendet')
                menu3.close()
                menu2.close()
                menu.close()
            end, function(data3, menu3)
                menu3.close()
            end)
        end, function(data2, menu2)
            menu2.close()
        end)
    end, function(data, menu)
        menu.close()
    end)
end

function ShowAllBills()
    local function openBillsMenu(bills)
        local elements = {}

for _, bill in pairs(bills) do
    local name = (bill.firstname and bill.lastname) and (bill.firstname .. ' ' .. bill.lastname) or 'Unbekannt'
    table.insert(elements, {
        label = ('%s - <span style="color:red;">$%s</span> | %s | %s'):format(
            bill.label,
            ESX.Math.GroupDigits(bill.amount),
            name,
            bill.id
        ),
        value = bill.id
    })
end


        if #elements == 0 then
            ESX.ShowNotification('Keine Rechnungen gefunden.')
            return
        end

        -- Füge Such-Button oben hinzu
        table.insert(elements, 1, {label = '🔍 Rechnung suchen', value = 'search'})

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'admin_bills', {
            title = 'Alle Rechnungen (Admin)',
            align = 'top-left',
            css   = 'rechnung',
            elements = elements
        }, function(data, menu)
            if data.current.value == 'search' then
                ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'search_bills', {
                    title = 'Suchbegriff eingeben (Grund oder Spielername)'
                }, function(data2, menu2)
                    local searchTerm = data2.value
                    if searchTerm == nil or searchTerm == '' then
                        ESX.ShowNotification('Ungültige Eingabe')
                    else
                        menu2.close()
                        menu.close()
                        ESX.TriggerServerCallback('billing:getAllBills', function(filteredBills)
                            openBillsMenu(filteredBills)
                        end, searchTerm)
                    end
                end, function(data2, menu2)
                    menu2.close()
                end)
            else
                -- Rechnung löschen Abfrage
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'confirm_delete', {
                    title = 'Rechnung löschen?',
                    align = 'top-left',
                    css   = 'rechnung',
                    elements = {
                        {label = '🗑️ Löschen', value = 'delete'},
                        {label = '❌ Abbrechen', value = 'cancel'}
                    }
                }, function(data2, menu2)
                    if data2.current.value == 'delete' then
                        TriggerServerEvent('billing:deleteBill', data.current.value)
                        ESX.ShowNotification('Rechnung gelöscht')
                        menu2.close()
                        menu.close()
                    else
                        menu2.close()
                    end
                end, function(data2, menu2)
                    menu2.close()
                end)
            end
        end, function(data, menu)
            menu.close()
        end)
    end

    -- Lade initial alle Rechnungen ohne Filter
    ESX.TriggerServerCallback('billing:getAllBills', function(bills)
        openBillsMenu(bills)
    end)
end
