#
# rpcclient parser
#
# (c) Aderstedt Software AB 2009.
#

import re, sys

path = re.compile('^path: (.*)$', re.MULTILINE)
comment = re.compile('^\s*comment:(.*)$', re.MULTILINE)
num_stores = re.compile('^\s*num_stores:\s*(\d+)', re.MULTILINE)
server = re.compile('^\s*storage\[\d+] server: (.*)$', re.MULTILINE)
share = re.compile('^\s*storage\[\d+] share: (.*)$', re.MULTILINE)
failure = re.compile('^.*NT_STATUS_(.*)$', re.MULTILINE);
nodeparser = re.compile("^(.*)\\\\([^\\\\]*)$")

def xmlSafe(s):
	c = s.replace('&','&amp;')
	c = c.replace('<','&lt;')
	c = c.replace('>','&gt;')
	return c

f = sys.stdin
s = f.read()
f.close()

print """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">"""

# Check for failure.
m = failure.search(s)
if m != None:
	reason = m.groups(1)[0]
	reason = ' '.join(reason.split('_')).capitalize()
	print "<dict><key>Error</key><true/><key>Reason</key><string>%s</string></dict>" % reason
else:

	# Create two lists, one with all the path matches and one with the indexes.
	matches = path.finditer(s);
	indexes = []
	pathnames = []
	for j in matches:
		pathnames.append(j.group(1))
		indexes.append(j.span()[0])
	indexes.append(len(s)-1)

	k = 0
	nodelist = {}
	rootpath = pathnames[0]
	for k in range(0, len(pathnames)):
		nodelist[pathnames[k]] = { "range":(indexes[k], indexes[k+1])}
		

	for node in nodelist:
		# Extract 'our' range of the string
		r = nodelist[node]["range"]
		substring = s[r[0]:r[1]]
		
		# Get the num_stores item. If it isn't there, then we skip this path.
		ns = num_stores.search(substring)
		if ns == None: continue
		ns = int(ns.group(1))
		
		# Comment field.
		cs = comment.search(substring)
		if cs != None and cs.group(1).strip() != "": 
			nodelist[node]["comment"] = cs.group(1).strip()
		
		# Servers and shares
		servers = server.findall(substring)
		shares = share.findall(substring)
		if (len(servers) != len(shares)) or (len(servers) != ns):
			sys.stderr.write('Malformed share entry for %s.\n', node)
			continue;
		shareList = {}
		for k in range(0, ns):
			shareList[servers[k]] = shares[k]
		
		nodelist[node]["shares"] = shareList
	
	def matchingItem(s, nodelist):
		sl = s.lower()
		for k in nodelist.keys():
			if sl == k.lower():
				return nodelist[k]
			if "subnodes" in nodelist[k].keys():
				p = findParentInTree(s, nodelist[k])
				if p != None:
					return p
		return None	
		
	def findParentInTree(parent, tree):
		# Walk the tree to find the key 'parent' in a subnodes dict.
		# Do a case insensitive-comparison.
		if "subnodes" not in tree.keys():
			return None
		subnodes = tree["subnodes"]
		s = parent.lower()
		for k in subnodes:
			if s == k.lower():
				return subnodes[k]
		for k in subnodes:
			result = findParentInTree(parent, tree["subnodes"][k])
			if result != None:
				return result
		return None

	#
	# Start by splitting all nodes into parts, and adding missing nodes.
	while len(nodelist.keys()) > 1:
		nodekeycopy = nodelist.keys()
		for node in nodekeycopy:
				
			if node == rootpath:
				continue
					
			m = nodeparser.match(node)
			parentKey = m.groups(1)[0]
			
			# Is it already in the tree?
			parent = findParentInTree(parentKey, nodelist[rootpath])
			if parent == None:
				# Is it in the nodelist? If not, add it.
				# ---> Or, it could also be a subnode of an item in the nodelist?
				
				parent = matchingItem(parentKey, nodelist)
				if parent == None:
					nodelist[parentKey] = {}
					parent = nodelist[parentKey]
				
			if "subnodes" not in parent.keys():
				parent["subnodes"] = {}
				
			parent["subnodes"][node] = nodelist[node]
			del nodelist[node]

	
	def writeNodeAndDescendents(node, parent, nodelist, lvl):
		print ('\t'*lvl)+'<dict>'
		print ('\t'*(lvl+1))+'<key>path</key><string>%s</string>' % (xmlSafe(node[(len(parent) + 1):]),)
		print ('\t'*(lvl+1))+'<key>numStores</key><integer>%d</integer>' % ns
		if "comment" in nodelist[node]:
			print ('\t'*(lvl+1))+'<key>comment</key><string>%s</string>' % xmlSafe(nodelist[node]["comment"])

		if "shares" in nodelist[node]:
			print ('\t'*(lvl+1))+'<key>shares</key>'
			print ('\t'*(lvl+1))+'<array>'
			for currentServer in nodelist[node]["shares"]:
				currentShare = nodelist[node]["shares"][currentServer]
				currentShare = currentShare.replace('\\','/')
				print ('\t'*(lvl+2))+'<dict><key>server</key><string>%s</string><key>share</key><string>%s</string></dict>' % (xmlSafe(currentServer), xmlSafe(currentShare))
			print ('\t'*(lvl+1))+'</array>'

		if "subnodes" in nodelist[node]:
			print ('\t'*(lvl+1))+'<key>subnodes</key>'
			print ('\t'*(lvl+1))+'<array>'
			# Sort subnodes according to path
			subnodes = nodelist[node]["subnodes"].keys()
			subnodes.sort(cmp=lambda x,y: cmp(x.lower(), y.lower()))
			for subnode in subnodes:
				writeNodeAndDescendents(subnode, node, nodelist[node]["subnodes"],lvl+2)
			print ('\t'*(lvl+1))+'</array>'
			
		print ('\t'*lvl)+'</dict>'
		
	# Remove shares from root
#	del nodelist[rootpath]["shares"]
	writeNodeAndDescendents(rootpath, "", nodelist, 0)

print '</plist>'
	