'use strict';

function renderFlights(data) {
    const table = document.querySelector('#flights_to');
    table.removeAttribute('class');
    table.innerHTML = `
        <caption>Выбор маршрута прямого перелета</caption>
        <tr class="flights__headers">
          <th class="flights__item">✓</th>
          <th class="flights__item">Путь</th>
          <th class="flights__item">Аэропорт отправления</th>
          <th class="flights__item">Аэропорт прибытия</th>
          <th class="flights__item">Время прибытия</th>
          <th class="flights__item">Пересадки</th>
        </tr>
    `;
    const submit = document.querySelector('#order_submit');
    submit.removeAttribute('class');
    submit.setAttribute('class', 'form-group');
    console.log(table);
    console.log(data);
    data['flights_to'].forEach(row => {
        const date_arr = new Date(row['ARRIVAL_DATE']);
        table.innerHTML += `
        <tr>
            <td class="flights__item">
                <input type="radio" name="flights_to" value="${row['FLIGHTS']}">
                <input type="hidden" name="client_id" value="${data['client']['ID']}"> 
                <input type="hidden" name="order_date" value="${data['order_date']}">
             </td>
             <td>${row['PATH']}</td>
             <td>${row['DEPARTURE_AIRPORT']}</td>
             <td>${row['ARRIVAL_AIRPORT']}</td>
             <td>${date_arr.toLocaleDateString()+' '+date_arr.toLocaleTimeString()}</td>
             <td>${(row['HOPS'] === 1)?"нет": row['HOPS']-1}</td>
        </tr>
        `
    });

    if (data['flights_from'].length > 0) {
        const table = document.querySelector('#flights_from');
        table.removeAttribute('class');
        table.innerHTML = `
            <caption>Выбор маршрута обратнного перелета</caption>
            <tr class="flights__headers">
              <th class="flights__item">✓</th>
              <th class="flights__item">Путь</th>
              <th class="flights__item">Аэропорт отправления</th>
              <th class="flights__item">Аэропорт прибытия</th>
              <th class="flights__item">Время прибытия</th>
              <th class="flights__item">Пересадки</th>
            </tr>
        `;
        data['flights_from'].forEach(row => {
            const date_arr = new Date(row['ARRIVAL_DATE']);
            table.innerHTML += `
            <tr>
                <td class="flights__item">
                    <input type="radio" name="flights_from" value="${row['FLIGHTS']}">
                    <input type="hidden" name="client_id" value="${data['client']['ID']}"> 
                    <input type="hidden" name="order_date" value="${data['order_date']}">
                 </td>
                 <td>${row['PATH']}</td>
                 <td>${row['DEPARTURE_AIRPORT']}</td>
                 <td>${row['ARRIVAL_AIRPORT']}</td>
                 <td>${date_arr.toLocaleDateString()+' '+date_arr.toLocaleTimeString()}</td>
                 <td>${(row['HOPS'] === 1)?"нет": row['HOPS']-1}</td>
            </tr>
            `
        });
    }
}

const form_order = document.querySelector('#order-form');

form_order.addEventListener('submit', function (event) {
    event.preventDefault();
    const formData = new FormData(form_order);

    const xhr = new XMLHttpRequest();

    xhr.open('POST','/getRoutes', true);

    xhr.onreadystatechange = function() {
        if (xhr.readyState === 4) {
            if(xhr.status === 200) {
                const data = JSON.parse(xhr.response);
                console.log( data);

                if (data['flights_to'].length > 0) {
                    renderFlights(data);
                }
            }
        }
    };

    xhr.send(formData);

});

// const form_flights = document.querySelector('#form-flights');
//
// form_flights.addEventListener('submit', function (event) {
//     event.preventDefault();
//     const formData = new FormData(form_flights);
//
//     const xhr = new XMLHttpRequest();
//
//     xhr.open('POST','/createOrder', true);
//
//     xhr.onreadystatechange = function() {
//         if (xhr.readyState === 4) {
//             if(xhr.status === 200) {
//                 const data = JSON.parse(xhr.response);
//                 console.log(typeof data);
//                 console.log(data)
//                 // if (data.length > 0) {
//                 //     renderFlights(data);
//                 // }
//             }
//         }
//     };
//
//     xhr.send(formData);
//
// });
//
