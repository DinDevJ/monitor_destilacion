# monitor_destilacion

Remasterizacion del monitor de destilacion antiguo. Servicio Social.

## A TOMAR EN CUENTA

Esta aplicacion es una remasterizacion de una aplicacion vieja pero casi no tiene nada de esta
unicamente se tomo en cuenta el algoritmo para leer los codigos de la maquina pero este a su vez
fue mejorado y optimizado por lo que se podria decir que es una aplicacion nueva

## ESTRUCTURA

La estructura de los archivos son los siguientes
/Lib
    /widgets <--- Este directorio guarda todo la vista de nuestra aplicacion
        pantalla_detalle.dart <-- Cuando le das a un elemento se abre la pestaña de detalle
        sensor_chart.dart <--- Las graficas de cada elemento en general (Presion, Temp, Humedad)
        sensor_chart_multi.dart <--- Aqui se ve la grafica pero cuando lo vez desde detalles
        vista_conexion.dart <--- La vista cuando estas buscando conexiones de bluetooth
        vista_monitor.dart <--- La vista de todos los elementos para un monitoreo rapido
    bluetooth_service.dart <--- Este script nos ayuda a enlazarnos efectivamente y sin errores
    excel_service.dart <--- Este exporta toda la informacion a un excel
    main.dart <--- Este junta todos los elementos anteriores y es el cerebro del sistema
