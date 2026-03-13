# Business_Central_extensions
Extension for Business central

## Quantity on Hand report – "Tenant Media does not exist" (ID=00000000)

If the report fails when sending email (scheduled or background) with this error:

1. In Business Central, search **Email Accounts** and open the page.
2. Open the account used for sending (the default account or the one assigned to **Quantity on Hand & Usage Report**).
3. Clear **Email Template** and **Logo** if they are set (or set them to a valid template/image). An empty or invalid media ID causes the error.
4. Save the account and run the report again.
