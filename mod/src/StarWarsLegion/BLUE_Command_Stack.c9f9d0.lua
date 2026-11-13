function onload(save_state)
    -- Spawned by script (the loader), a custom bag is only a container once
    -- its model has loaded; on a save load it already is.
    Wait.condition(updateStack, function() return not self.loading_custom end)
end

function onObjectLeaveContainer(container, leave_object)
    if container == self then
        updateStack()
    end
end

function updateStack()
    local tokenObjs = self.getObjects()
    if #tokenObjs == 0 then
        self.setColorTint({65/255,88/255,114/255})
        self.setScale({1,1,1})
    else
        self.setScale({1,#tokenObjs,1})
        self.setColorTint({1,1,1})
    end
end
