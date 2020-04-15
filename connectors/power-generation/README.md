# Power consumption in Spain
This connector uses the public API of the Spanish grid operator.
### The REST URL
````
let url = 'https://apidatos.ree.es/en/datos/demanda/evolucion?start_date='
  + year + '-01-01&end_date='
  + (1 + year) + '-01-01&time_trunc=day';
````

### Issues
Just getting the data for the current year will of course fail to work well after the end of this year.
