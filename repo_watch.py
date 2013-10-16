#!/usr/bin/python
# -*- coding: utf-8 -*-
import xmpp
import time

__version__="0.1 - 20120926 11:29:55"
__changelog__="""
0.1 - 20120906
- initial version
"""

seen = {}
commands={}

i18n={'ru':{},'en':{}}
i18n['en']['HELP']="Fuzzy bot. Go away!\nAvailable commands: %s"
i18n['en']['EMPTY']="%s"
i18n['en']['HOOK1']='Responce 1: %s'
i18n['en']['HOOK2']='Responce 2: %s'
i18n['en']['HOOK3']='Responce 3: static string'
i18n['en']["UNKNOWN COMMAND"]='Unknown command "%s". Go away!'
i18n['en']["UNKNOWN USER"]="I do not know you. Go away!"


def verHandler(user,command,args,mess):
    return "", "%s"%__version__

############################ bot logic start #####################################
def messageCB(conn,mess):
    text=mess.getBody()
    user=mess.getFrom()
    global seen
    seen[user] = user
    #print text
    #print user.getStripped()
    user.lang='en'      # dup
    
    if user.getStripped()=='github-services@jabber.org' and text.find('new commits to master'): print "New commits..."
    time.sleep(5)


for i in globals().keys():
    if i[-7:]=='Handler' and i[:-7].lower()==i[:-7]: commands[i[:-7]]=globals()[i]



############################# bot logic stop #####################################

def StepOn(conn):
    try:
        conn.Process(1)
    except KeyboardInterrupt: return 0
    return 1

def GoOn(conn):
    while StepOn(conn): pass

if __name__=="__main__":
    config = {}
    execfile("repo_watch.cfg", config)

    jid=xmpp.JID(config["login"])
    user,server,password=jid.getNode(),jid.getDomain(),config["password"]

    conn=xmpp.Client(server,debug=[])

    conres=conn.connect()

    if not conres:
        print "Unable to connect to server %s!"%server
        sys.exit(1)
    if conres<>'tls':
        print "Warning: unable to estabilish secure connection - TLS failed!"
    authres=conn.auth(user,password)
    if not authres:
        print "Unable to authorize on %s - check login/password."%server
        sys.exit(1)
    if authres<>'sasl':
        print "Warning: unable to perform SASL auth os %s. Old authentication method used!"%server
    conn.RegisterHandler('message',messageCB)
    conn.sendInitPresence()

    presence = xmpp.Presence(status = "NOT READY!", show= 'dnd', priority = '1')
    conn.send(presence)
    conn.Process(1)

    GoOn(conn)

    presence = xmpp.Presence(status = "NOT READY!", show= 'dnd', priority = '1')
    conn.send(presence)
    conn.Process(1)
