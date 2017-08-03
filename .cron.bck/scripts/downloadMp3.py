import sys
sys.path.insert(0, '/home/arthur/Dropbox-prive/install-server/KickassAPI')

from KickassAPI import Search, Latest, User, CATEGORY, ORDER

#print next(iter(Search(sys.argv[1]))).magnet_link
print next(iter(Search(sys.argv[1]).category(CATEGORY.MUSIC))).magnet_link
