ESX = exports['es_extended']:getSharedObject()

local allowedJobs = {
    police = 'society_police',
    mechanic = 'society_mechanic',
    ambulance = 'society_ambulance'
}

ESX.RegisterServerCallback('billing:getBills', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local result = MySQL.query.await('SELECT amount, id, label FROM billing WHERE identifier = ?', {xPlayer.identifier})
    cb(result)
end)

ESX.RegisterServerCallback('billing:isAdmin', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    cb(xPlayer.getGroup() == 'admin')
end)

RegisterServerEvent('billing:createBill')
AddEventHandler('billing:createBill', function(targetId, label, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    local xTarget = ESX.GetPlayerFromId(targetId)
    if not xTarget then return end

    if not allowedJobs[xPlayer.job.name] then return end

    local society = allowedJobs[xPlayer.job.name]
    amount = ESX.Math.Round(amount)
    if amount <= 0 then return end

    MySQL.insert('INSERT INTO billing (identifier, sender, target_type, target, label, amount) VALUES (?, ?, ?, ?, ?, ?)', {
        xTarget.identifier, xPlayer.identifier, 'society', society, label, amount
    })

    xTarget.showNotification('Du hast eine neue Rechnung erhalten')
end)

RegisterServerEvent('billing:payBill')
AddEventHandler('billing:payBill', function(billId)
    local xPlayer = ESX.GetPlayerFromId(source)
    local result = MySQL.single.await('SELECT sender, target_type, target, amount FROM billing WHERE id = ?', {billId})
    if not result then return end

    local amount = result.amount
    local xTarget = ESX.GetPlayerFromIdentifier(result.sender)
    local paymentAccount = 'money'

    if xPlayer.getMoney() < amount then
        paymentAccount = 'bank'
        if xPlayer.getAccount('bank').money < amount then
            xPlayer.showNotification('Nicht genug Geld')
            return
        end
    end

    local rowsChanged = MySQL.update.await('DELETE FROM billing WHERE id = ?', {billId})
    if rowsChanged ~= 1 then return end

    local payout = ESX.Math.Round(amount * 0.15)
    xPlayer.removeAccountMoney(paymentAccount, amount, "Rechnung bezahlt")

    TriggerEvent('esx_addonaccount:getSharedAccount', result.target, function(account)
        account.addMoney(amount - payout)
    end)

    if xTarget then
        xTarget.addAccountMoney(paymentAccount, payout)
        xTarget.showNotification(('Du hast $%s für eine bezahlte Rechnung erhalten'):format(payout))
    end

    xPlayer.showNotification(('Du hast eine Rechnung über $%s bezahlt'):format(amount))
end)

RegisterServerEvent('esx:payAllBills')
AddEventHandler('esx:payAllBills', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    local result = MySQL.query.await('SELECT id FROM billing WHERE identifier = ?', {xPlayer.identifier})
    for _, bill in pairs(result) do
        TriggerEvent('billing:payBill', bill.id)
    end
end)


ESX.RegisterServerCallback('billing:getAllBills', function(source, cb, search)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin' then
        local query = [[
            SELECT b.id, b.label, b.amount, b.identifier, u.firstname, u.lastname 
            FROM billing b 
            LEFT JOIN users u ON b.identifier = u.identifier
        ]]
        local params = {}

        if search and search ~= '' then
            search = '%' .. search .. '%'
            query = query .. ' WHERE b.label LIKE ? OR u.firstname LIKE ? OR u.lastname LIKE ?'
            params = {search, search, search}
        end

        local result = MySQL.query.await(query, params)
        cb(result)
    else
        cb({})
    end
end)


RegisterServerEvent('billing:deleteBill')
AddEventHandler('billing:deleteBill', function(billId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin' then
        MySQL.update('DELETE FROM billing WHERE id = ?', {billId})
        xPlayer.showNotification('Rechnung wurde gelöscht.')
    else
        xPlayer.showNotification('Keine Berechtigung.')
    end
end)
