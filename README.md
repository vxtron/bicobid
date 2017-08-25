# bicobid

=== Installation ===
1. Install Ruby (Windows: https://rubyinstaller.org/ )
2. Start a console and install dependencies: gem install httpclient
3. Install "Web Developer" extension in Firefox or any other add-on
   allowing you to easily view cookies for the current site.

=== Preparation ===
1. Log into Binance and open the respective ICO page.
2. Write down the project ID (you'll find that in the URL, e.g., 7), the price
   (e.g., 0.00000448) and decide on the amount of tokens to buy (e.g., balance
   divided by price, minus 1% to be on the safe side). Amounts with decimals
   are not supported by Binance.
3. Get the values of the JSESSIONID and CSRFToken cookies from your
   browser session. With Web Developer add-on installed:
     - Right-click the webpage
     - Select Web Developer / Cookies / View Cookie Information

=== Bidding ===

Run the script (use --help for all options):

  bicobid.rb --id 7 --price 0.00000448 --amount 1000 --session 5DDAE1... --csrf AA95F...

If you're sleepy and value your account, it's probably not a good idea to hammer
Binance throughout the night. You can use the --start parameter to wait with the
bidding until a certain time (make sure your clock is correct). Leave the browser
open on the trading page of a token so the session (hopefully) does not expire:

  bicobid.rb -id 7 ... --start "2017-08-25 13:59:50"

By default, bidding will stop after 300 seconds (see --duration).

After a bid, the info returned by the server is output (and also appended to
the file bicobid.log in the current directory).
As the text returned is in chinese, a non-utf8 capable terminal (the Windows
console) will not display those characters properly. Open bicobid.log in
notepad - this should allow you to copy the text and put it into
translate.google.com.

=== Errors ===

   该阶段不能购买产品!   - "The stage can not buy the product!" = The ICO
   hasn't started yet or is closed already.
