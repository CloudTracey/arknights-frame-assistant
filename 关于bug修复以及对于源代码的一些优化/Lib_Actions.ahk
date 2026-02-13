ActionPauseselect(ThisHotkey) 
{
    Critical("On")
    Send("{ESC Up}{ESC Down}")
    USleep(Delay)
    Send("{Click Left}")
    Send("{ESC Up}")
    USleep(Delay * 1.6)
    Send("{ESC Down}"), USleep(Delay), Send("{ESC Up}")
    Critical("Off")
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
}

ActionPauseSkill(ThisHotkey) 
{
    Critical("On")
    Send("{ESC Up}{ESC Down}")
    USleep(Delay)
    Send("{Click Left}")
    Send("{ESC Up}")
    USleep(Delay * 1.8)
    Send("{ESC Down}"), USleep(Delay), Send("{ESC Up}")
    Send("{e Down}"), USleep(Delay * 1.2), Send("{e Up}")
    Critical("Off")
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
}

ActionPauseRetreat(ThisHotkey) 
{
    Critical("On")
    Send("{ESC Up}{ESC Down}")
    USleep(Delay)
    Send("{Click Left}")
    Send("{ESC Up}")
    USleep(Delay * 1.8)
    Send("{ESC Down}"), USleep(Delay), Send("{ESC Up}")
    Send("{q Down}"), USleep(Delay * 1.2), Send("{q Up}")
    Critical("Off")
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
}

ActionPause(ThisHotkey) 
{
    Critical("On") 
    Send("{ESC Down}"), USleep(Delay), Send("{ESC Up}")
    Critical("Off")
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
}

ReleasePause(ThisHotkey) 
{
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
    Critical("On")
    Send("{ESC Down}"), USleep(Delay), Send("{ESC Up}")
    Critical("Off")
}

ActionGameSpeed(ThisHotkey) 
{
    Critical("On") 
    Send("{f Down}"), USleep(Delay), Send("{f Up}")
    Send("{g Down}"), USleep(Delay), Send("{g Up}")
    Critical("Off")
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
}

Action33ms(ThisHotkey) 
{
    Critical("On")
    Send("{ESC Down}"), USleep(Delay), Send("{ESC Up}"), USleep(29 - Delay), Send("{ESC Down}"), USleep(Delay), Send("{ESC Up}")
    Critical("Off")
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
}

Action166ms(ThisHotkey) 
{
    Critical("On")
    Send("{ESC Down}"), USleep(Delay), Send("{ESC Up}"), USleep(166 - Delay), Send("{ESC Down}"), USleep(Delay), Send("{ESC Up}")
    Critical("Off")
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
}

ActionSkill(ThisHotkey) 
{
    Critical("On")
    Send("{e Down}"), USleep(Delay), Send("{e Up}")
    Critical("Off")
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
}

ActionRetreat(ThisHotkey) 
{
    Critical("On")
    Send("{q Down}"), USleep(Delay), Send("{q Up}")
    Critical("Off")
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
}

ActionOneClickSkill(ThisHotkey) 
{
    Critical("On")
    Send("{Click Left}"), USleep(Delay * 1.5), Send("{e Down}"), USleep(Delay * 1.3), Send("{e Up}")
    Critical("Off")
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
}

ActionOneClickRetreat(ThisHotkey) 
{
    Critical("On")
    Send("{Click Left}"), USleep(Delay * 1.5), Send("{q Down}"), USleep(Delay * 1.3), Send("{q Up}")
    Critical("Off")
    if !InStr(ThisHotkey, "Wheel") 
        KeyWait(ThisHotkey)
}