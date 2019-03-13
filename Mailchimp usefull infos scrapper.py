f=open("data","r")
res=open("res","a")
for x in f:
    spl=x.split(",")
    mail=spl[0]
    last=spl[1]
    first=spl[2]
    res.write("Courriel: ")
    res.write(mail)
    res.write(" Nom:")
    res.write(last)
    res.write(" Prénom:")
    res.write(first)
    res.write("\n")
    res.write("\n")
res.close()
f.close()

