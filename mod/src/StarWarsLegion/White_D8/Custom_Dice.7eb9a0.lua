require('!/Brain')

function ondestroy() dieRollerInfo = Brain().getTable('dieRollerInfo') dieRoller = getObjectFromGUID(dieRollerInfo.redDieRollerGUID) dieRoller.call('waitToUpdate') end












