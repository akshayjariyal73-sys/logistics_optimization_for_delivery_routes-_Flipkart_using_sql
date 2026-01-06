create database `logistics optimization for delivery routes – flipkart` ;
show tables ;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Task 1: Data Cleaning & Preparation
-- Task 1.1: Identify and delete duplicate Order_ID records

select * from flipkart_orders ;
select count(*) as 'No. of rows', count(distinct order_id) as Distinct_order_ID from flipkart_orders ; # No duplicate order_id are there.
-- to delete duplicate Order_id records
delete from flipkart_orders where Order_ID in
 (select order_id from 
(select order_id,row_number() over (partition by order_id) as Rownum 
from flipkart_orders)t1 where  rownum > 1);

--											or

select order_id,count(*) as 'number of order id' from flipkart_orders  where 'number of order id' > 1 group by order_id ;

-- 											or
select order_id,count(*) as 'number of order id' from flipkart_orders  group by order_id having 'number of order id' > 1
union all
select 'no duplicate found' as order_id,null as 'number of order id' where not exists
(SELECT order_id
    FROM flipkart_orders
    GROUP BY order_id
    HAVING COUNT(*) > 1 );
    
    
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Task 1.2: Replace null Traffic_Delay_Min with the average delay for that route.

select round(avg(Traffic_Delay_Min),2) as Avg_traffic_delay  from flipkart_routes ;

select Traffic_Delay_Min from flipkart_routes where Traffic_Delay_Min is null ; # no null place in traffic_delay_min

-- To Replace null Traffic_Delay_Min with the average delay for that route
UPDATE flipkart_routes r1
INNER JOIN
(SELECT route_id, ROUND(AVG(Traffic_Delay_Min), 2) AS Avg_delay
FROM flipkart_routes AS r2
WHERE Traffic_Delay_Min IS NOT NULL
GROUP BY route_id) AS avg_table ON r1.route_id = avg_table.route_id 
SET 
r1.Traffic_Delay_Min = avg_table.Avg_delay
WHERE Traffic_Delay_Min IS NULL;
 
 
 -------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
# Task 1.3:  Convert all date columns into YYYY-MM-DD format using SQL functions.
   UPDATE flipkart_orders
SET Order_Date = STR_TO_DATE(Order_Date, '%Y-%m-%d'),
Expected_Delivery_Date = STR_TO_DATE(Expected_Delivery_Date, '%Y-%m-%d'),
Actual_Delivery_Date = STR_TO_DATE(Actual_Delivery_Date, '%Y-%m-%d');

UPDATE flipkart_shipmenttracking
SET Checkpoint_Time = STR_TO_DATE(Checkpoint_Time, '%Y-%m-%d %H:%i:%s');

 alter table flipkart_orders 
  modify Expected_Delivery_Date date,
  modify Order_Date date,
  modify Actual_Delivery_Date date ;
  
alter table flipkart_shipmenttracking 
modify Checkpoint_Time datetime  ;

select * from flipkart_shipmenttracking ;
  select * from flipkart_orders ;



UPDATE flipkart_shipmenttracking 
SET 
    Checkpoint_Time = STR_TO_DATE(Checkpoint_Time, '%Y-%m-%d %H:%i:%s');


---------------------------------------------------------------------------------------------------------------------------------------------------------------

# Task 1.4: Ensure that no Actual_Delivery_Date is before Order_Date (flag such records).

alter table flipkart_orders add column `Actual_Delivery_Date is before Order_Date (Flags)` int ;
select * from flipkart_orders ;
update flipkart_orders set `Actual_Delivery_Date is before Order_Date (Flags)` =
case when Actual_Delivery_Date < Order_Date then 1 
else 0 
end ;        # no actual delivery date is before order date

select * from flipkart_orders where Actual_Delivery_Date < Order_Date ;
select * from flipkart_orders where `Actual_Delivery_Date is before Order_Date (Flags)` = 1;


alter table flipkart_orders rename column `Actual_Delivery_Date is before Order_Date` to `Actual_Delivery_Date is before Order_Date (Flags)` ;


update flipkart_orders set `Actual_Delivery_Date is before Order_Date (Flags)` = 1 where Actual_Delivery_Date < Order_Date ;

update flipkart_orders set `Actual_Delivery_Date is before Order_Date` = 0 where Actual_Delivery_Date > Order_Date ;

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

 # Task 2: Delivery Delay Analysis
-- Task 2.1 : Calculate delivery delay (in days) for each order

select order_id, Order_Date,Expected_Delivery_Date,Actual_Delivery_Date,
 datediff(Actual_Delivery_Date,Expected_Delivery_Date) as `delivery delay in days` from flipkart_orders
 order by `delivery delay in days` desc; 
 
 alter table flipkart_orders add column `Delivery delay in days`int ;
 update flipkart_orders set `Delivery delay in days` = datediff(Actual_Delivery_Date,Expected_Delivery_Date) ;
 
 
 
 
 alter table flipkart_orders drop column `Delivery delay (in days)` ;
 alter table flipkart_orders add column ` (Flag)Delivery delay (in days)`int ;
 update flipkart_orders set `Delivery delay (in days)` = 
 case 
 when Actual_Delivery_Date>Expected_Delivery_Date then 1 else 0 end ;
 
select * from flipkart_orders ;
select Route_ID, sum(case when `Delivery delay (in days)`> 0 then 1 else 0 end) as count_of_routes from flipkart_orders group by Route_ID ;
select sum(case when `Delivery delay (in days)`> 0 then 1 else 0 end) from flipkart_orders ;
select Route_ID,count(Route_ID) as count_of_routes from flipkart_orders group by Route_ID ;
----------------------------------------------------------------------------------------------------------------------------------------------------------------
 -- Task 2.2: Find Top 10 delayed routes based on average delay days.
select * from flipkart_routes ;
select * from flipkart_orders ;
select avg(`Delivery delay (in days)`) from flipkart_orders ;
 -- Task 2.2: Find Top 10 delayed routes based on average delay days.
 
select route_id , avg(datediff(Actual_Delivery_Date,Expected_Delivery_Date)) as Avg_delay_days
 from flipkart_orders group by Route_ID order by Avg_delay_days desc limit 10 ;
                                -- or
select o.route_id , avg(datediff(o.Actual_Delivery_Date,o.Expected_Delivery_Date)) as Avg_delay_days,
count(o.Order_ID) as total_orders,
sum(case 
when datediff(o.Actual_Delivery_Date, o.Expected_Delivery_Date) > 0 then 1
ELSE 0 
END) AS Delayed_Orders,
r.Start_Location,r.End_Location,r.Distance_KM from flipkart_orders o
left join flipkart_routes r on o.Route_ID=r.Route_ID
 group by Route_ID,r.Start_Location,r.End_Location,r.Distance_KM order by Avg_delay_days desc limit 10 ;
 
 -----------------------------------------------------------------------------------------------------------------------------------------------------
 
 # Task 2.3 : Use window functions to rank all orders by delay within each warehouse.
 
 select o.order_id,o.route_id,o.Warehouse_ID,w.warehouse_name,datediff(o.Actual_Delivery_Date,o.Expected_Delivery_Date) as delay_in_days,
 rank() over ( partition by o.Warehouse_ID order by o.Warehouse_ID,datediff(o.Actual_Delivery_Date,o.Expected_Delivery_Date )desc
) as ranks 
   from flipkart_orders o left join flipkart_warehouses w on o.Warehouse_ID = w.Warehouse_ID;

                              -- or 
WITH RankedOrders AS (SELECT Warehouse_ID,
RANK() OVER (PARTITION BY Warehouse_ID ORDER BY datediff(Actual_Delivery_Date,Expected_Delivery_Date ) DESC) as Delay_Rank
FROM flipkart_orders
)
SELECT * FROM RankedOrders ORDER BY Warehouse_ID, Delay_Rank;




select warehouse_id,count(*) from flipkart_orders group by Warehouse_ID ;
-----------------------------------------------------------------------------------------------------------------------------------------------------------

# Task 3: Route Optimization Insights
-- Task 3.1 For each route, calculate:
--  Average delivery time (in days).
select route_id, round(avg(datediff(Actual_Delivery_Date,Order_Date)),2) as Avg_Delivery_In_Days from flipkart_orders 
group by Route_ID order by Avg_Delivery_In_Days desc ;
                                  -- or
select r.Route_ID,r.Start_Location,r.End_Location,r.Distance_KM,
  COUNT(o.Order_ID) AS Total_Orders,
  ROUND(AVG(DATEDIFF(o.Actual_Delivery_Date, o.Order_Date)), 2) AS Avg_Delivery_In_Days
FROM flipkart_routes r
LEFT JOIN flipkart_orders o 
  ON r.Route_ID = o.Route_ID 
GROUP BY r.Route_ID, r.Start_Location, r.End_Location, r.Distance_KM
ORDER BY Avg_Delivery_In_Days DESC;

------------------------------------------------------------------------------------------------------------------------------------------------
-- Average traffic delay.
select route_id , round(avg(Traffic_Delay_Min),2) as avg_traffic_delay from flipkart_routes group by Route_ID ;


-- Distance-to-time efficiency ratio: Distance_KM / Average_Travel_Time_Min.

select Route_ID, round(Distance_KM/Average_Travel_Time_Min,2) as efficiency_ratio from flipkart_routes order by efficiency_ratio desc;

select Route_ID,Distance_KM,Average_Travel_Time_Min, round(Distance_KM/Average_Travel_Time_Min,2) as efficiency_ratio
 from flipkart_routes group by Route_ID,Distance_KM,Average_Travel_Time_Min order by efficiency_ratio desc;
---------------------------------------------------------------------------------------------------------------------------------------------------
# Task 3.2 : Identify 3 routes with the worst efficiency ratio.

select *, round(Distance_KM/Average_Travel_Time_Min,2) as efficiency_ratio from flipkart_routes order by efficiency_ratio asc limit 3 ;

----------------------------------------------------------------------------------------------------------------------------------------------------
# Task 3.3 Find routes with >20% delayed shipments.
select * from flipkart_routes ;
select r.route_id,concat(r.start_location,'->',r.end_location) as locations,
count(o.order_id) as total_orders,
sum(case when datediff(o.Actual_Delivery_Date,o.Expected_Delivery_Date) >0 then 1 else 0 end) as delay_orders,
round(sum(case when datediff(o.Actual_Delivery_Date,o.Expected_Delivery_Date) > 0 then 1 else 0 end)/count(*)*100,2) as delayed_percentage
from flipkart_orders o
left join flipkart_routes r on r.Route_ID = o.Route_ID
group by r.route_id,r.start_location,r.end_location
having delayed_percentage > 20
order by delayed_percentage desc;

------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Task 3.4 : Recommend potential routes for optimization.
 select r.route_id,concat(r.start_location,'->',r.end_location) as locations,
count(o.order_id) as total_orders,
round(r.Distance_KM/r.Average_Travel_Time_Min,2) as efficiency_ratio,
round(avg(r.Traffic_Delay_Min),2) as avg_traffic_delay,
sum(case when datediff(o.Actual_Delivery_Date,o.Expected_Delivery_Date) >0 then 1 else 0 end) as delay_orders,
round(sum(case when datediff(o.Actual_Delivery_Date,o.Expected_Delivery_Date) > 0 then 1 else 0 end)/count(*)*100,2) as delayed_percentage
from flipkart_orders o
left join flipkart_routes r on r.Route_ID = o.Route_ID
group by r.route_id,r.start_location,r.end_location,r.Distance_KM,r.Average_Travel_Time_Min
having delayed_percentage > 20 or efficiency_ratio < 0.5
order by delayed_percentage desc;

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Task 4: Warehouse Performance 
-- Task 4.1 : Find the top 3 warehouses with the highest average processing time.

select * from flipkart_warehouses 
order by Average_Processing_Time_Min desc
limit 3 ;

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Task 4.2 Calculate total vs. delayed shipments for each warehouse. 

select w.Warehouse_ID,w.Warehouse_Name,w.City,
count(o.order_id) as total_orders,
sum(case when datediff(o.Actual_Delivery_Date,o.Expected_Delivery_Date) >0 then 1 else 0 end ) as delayed_shipment,
sum(case when datediff(o.Actual_Delivery_Date,o.Expected_Delivery_Date) = 0 then 1 else 0 end ) as shipment_on_time,
sum(case when datediff(o.Actual_Delivery_Date,o.Expected_Delivery_Date) >0 then 1 else 0 end )/count(*) * 100  as perecent_delay
from flipkart_orders o
join 
flipkart_warehouses w on w.Warehouse_ID=o.Warehouse_ID
group by w.Warehouse_ID,w.Warehouse_Name,w.City ;

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Task 4.3 : Use CTEs to find bottleneck warehouses where processing time > global average.

with cte as 
(
select round(avg(Average_Processing_Time_Min),2) as global_average from flipkart_warehouses
)
select w.* from flipkart_warehouses as w, cte 
where w.Average_Processing_Time_Min > cte.global_average ;
 -- or
WITH cte AS (
    SELECT ROUND(AVG(Average_Processing_Time_Min), 2) AS global_average FROM flipkart_warehouses
)
SELECT w.* 
FROM flipkart_warehouses w 
CROSS JOIN cte 
WHERE w.Average_Processing_Time_Min > cte.global_average;

-- or

select * from flipkart_warehouses where Average_Processing_Time_Min > (select round(avg(Average_Processing_Time_Min),2) as global_average from flipkart_warehouses);

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Task 4.4 : Rank warehouses based on on-time delivery percentage

select w.Warehouse_ID,w.Warehouse_Name,
count(*) as total_orders,
sum(case when datediff(Actual_Delivery_Date,Expected_Delivery_Date) = 0 then 1 else 0 end) as On_time_delivery,
sum(case when datediff(Actual_Delivery_Date,Expected_Delivery_Date) = 0 then 1 else 0 end)/count(*)*100 as On_time_delivery_percentage,
rank() over ( order by sum(case when datediff(Actual_Delivery_Date,Expected_Delivery_Date) = 0 then 1 else 0 end)/count(*)*100 desc)  as ranking
from flipkart_orders o 
join flipkart_warehouses w on o.Warehouse_ID=w.Warehouse_ID
group by w.Warehouse_ID,w.Warehouse_Name ;

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Task 5: Delivery Agent Performance
-- Task 5.1 : Rank agents (per route) by on-time delivery percentage
select * from flipkart_deliveryagents ;
select agent_id,agent_name,route_id,On_Time_Delivery_Percentage,
rank() over (partition by Route_ID order by On_Time_Delivery_Percentage desc) as Ranking
from flipkart_deliveryagents ;

----------------------------------------------------------------------------------------------------------------------------------------------------------------

# Task 5.2 : Find agents with on-time % < 80%.
 select * from flipkart_deliveryagents where On_Time_Delivery_Percentage < 80 
 order by On_Time_Delivery_Percentage desc;
 
 ------------------------------------------------------------------------------------------------------------------------------------------------------------------
 # Task 5.3 : Compare average speed of top 5 vs bottom 5 agents using subqueries.
 
select 
(select avg(Avg_Speed_KMPH) from 
(select Avg_Speed_KMPH from flipkart_deliveryagents order by Avg_Speed_KMPH desc limit 5)as top_5 ) avg_top5_agents,
(select round(avg(Avg_Speed_KMPH),2) from 
(select Avg_Speed_KMPH from flipkart_deliveryagents order by Avg_Speed_KMPH asc limit 5)as bottom_5 )as avg_bottom5_agents;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Training Strategies Find the gaps. Start by identifying where each agent struggles — it could be route navigation, communication with customers, or handling packages correctly.
 -- Train with purpose. Offer short workshops or online sessions that focus on these weak areas, such as how to use route optimization tools or manage deliveries more efficiently.

-- Use mentorship. Pair low-performing agents with experienced ones so they can learn from real situations and get practical tips.

-- Give regular feedback. Sit down often to discuss what’s going well, what needs work, and clear steps for improvement.

-- Practice real scenarios. Organize simulations that mimic challenging delivery situations so agents can build confidence and make better decisions on the job.

-- Workload Balancing Strategies
-- Redistribute routes. Start new or low-performing agents on simpler or shorter routes. This helps them gain experience without feeling overwhelmed.

-- Mix the teams. Combine strong and weaker performers across routes or shifts to encourage teamwork and peer learning.

-- Reward progress. Offer small incentives or recognition when agents show steady improvement or hit specific goals.

-- Avoid overload. Keep the workload manageable to prevent mistakes and burnout, which often lead to delays.

-- Keep monitoring. Track performance regularly and adjust assignments based on each agent’s growing capacity and progress.

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Task 6: Shipment Tracking Analytics 
-- Task 6.1 : For each order, list the last checkpoint and time.

select order_id,checkpoint,checkpoint_time from 
(select order_id,checkpoint,checkpoint_time,row_number() over (partition by order_id order by checkpoint_time desc) as row_numbers
 from flipkart_shipmenttracking) as ranks
 where row_numbers = 1 ; 
                                                 -- or we can use this
 with cte_order as ( select order_id,checkpoint,checkpoint_time,row_number() over (partition by order_id order by checkpoint_time desc) as ranks
 from flipkart_shipmenttracking)
 select c.order_id,c.checkpoint,c.checkpoint_time from cte_order c
 inner join flipkart_orders o on o.Order_ID = c.Order_ID and ranks =1 ;
 
 --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Task 6.2 : Find the most common delay reasons (excluding None).
select Delay_Reason,count(*) as delay_counts from flipkart_shipmenttracking
where Delay_Reason != 'none' group by delay_reason order by delay_counts desc ;

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Task 6.3 : Identify orders with >2 delayed checkpoints
select order_id,count(delay_minutes) as delayed_checkpoints from flipkart_shipmenttracking
 where delay_minutes > 0
 group by order_id
 having count(Delay_Minutes) > 2
 order by delayed_checkpoints asc;
 
 ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Task 7: Advanced KPI Reporting
  -- Calculate KPIs using SQL queries:
   -- Task 7.1 : Average Delivery Delay per Region (Start_Location).
select r.start_location as Region,count(o.order_id) as Total_orders,
round(avg(datediff(o.Actual_Delivery_Date,o.Expected_Delivery_Date)),2) as avg_deylay_days,
sum( case when o.Actual_Delivery_Date>o.Expected_Delivery_Date then 1 else 0 end) as delayed_orders,
round(100*sum( case when o.Actual_Delivery_Date>o.Expected_Delivery_Date then 1 else 0 end)/count(o.order_id),2) as delayed_orders_percentage
from flipkart_orders o
join flipkart_routes r on o.Route_ID=r.Route_ID 
group by r.Start_Location 
order by avg_deylay_days desc;


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Task 7.2 : On-Time Delivery % = (Total On-Time Deliveries / Total Deliveries) * 100
-- overall
select count(Order_ID) as total_orders,
sum(case when Actual_Delivery_Date<=Expected_Delivery_Date then 1 else 0 end) as  total_on_time_deliveries,
round(100*sum(case when Actual_Delivery_Date<=Expected_Delivery_Date then 1 else 0 end)/count(order_id),2) as 'On_time_delivery_%'
from flipkart_orders where `status` = 'delivered';
-- by warehouses
select w.Warehouse_Name,count(o.Order_ID) as total_orders,
sum(case when o.Actual_Delivery_Date<=o.Expected_Delivery_Date then 1 else 0 end) as total_on_time_deliveries,
round(100*sum(case when o.Actual_Delivery_Date<=o.Expected_Delivery_Date then 1 else 0 end)/count(o.order_id),2) as 'On_time_delivery_%'
from flipkart_orders o left join flipkart_warehouses w on o.Warehouse_ID=w.Warehouse_ID 
where o.status = 'delivered'
group by w.Warehouse_Name;
-- by region/routes
select r.Start_Location as Region,count(o.Order_ID) as total_orders,
round(100*sum(case when o.Actual_Delivery_Date<=o.Expected_Delivery_Date then 1 else 0 end)/count(o.order_id),2) as 'On_time_delivery_%'
from flipkart_orders o left join flipkart_routes r on o.Route_ID=r.Route_ID 
where o.status = 'delivered'
group by r.Start_Location
order by `On_time_delivery_%` desc ;
-------------------------------------------------------------------------------------------------------------------------------------------------------------------

# Task 7.3 : Average Traffic Delay per Route.

select r.Route_ID,count(o.order_id) as total_orders,
avg(r.Traffic_Delay_Min) as Avg_Traffic_delay
from flipkart_routes r 
left join flipkart_orders o on r.route_id = o.Route_ID
group by r.Route_ID
order by  Avg_Traffic_delay desc;

-- or

SELECT 
  Route_ID, 
  ROUND(AVG(Traffic_Delay_Min), 2) AS Avg_Traffic_Delay_Min
FROM flipkart_routes
GROUP BY Route_ID
ORDER BY Avg_Traffic_Delay_Min DESC;
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------


WITH KPI AS (
  SELECT
    COUNT(*) as Total_Orders,
    ROUND(100.0 * SUM(CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 ELSE 0 END) / COUNT(*), 2) as OnTime_Percentage,
    ROUND(AVG(DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date)), 2) as Avg_Delay_Days,
    SUM(Order_Value) as Total_Order_Value
  FROM flipkart_orders
  WHERE Status = 'Delivered'
),
WarehouseStats AS (
  SELECT 
    COUNT(*) as Total_Warehouses,
    ROUND(AVG(Average_Processing_Time_Min), 2) as Avg_Processing_Time
  FROM flipkart_warehouses
),
RouteStats AS (
  SELECT 
    COUNT(*) as Total_Routes,
    ROUND(AVG(Traffic_Delay_Min), 2) as Avg_Traffic_Delay
  FROM flipkart_routes
),
AgentStats AS (
  SELECT 
    COUNT(*) as Total_Agents,
    ROUND(AVG(On_Time_Delivery_Percentage), 2) as Avg_Agent_Performance
  FROM flipkart_deliveryagents
)
SELECT
  k.Total_Orders,
  k.OnTime_Percentage,
  k.Avg_Delay_Days,
  k.Total_Order_Value,
  w.Total_Warehouses,
  w.Avg_Processing_Time,
  r.Total_Routes,
  r.Avg_Traffic_Delay,
  a.Total_Agents,
  a.Avg_Agent_Performance
FROM KPI k
CROSS JOIN WarehouseStats w
CROSS JOIN RouteStats r
CROSS JOIN AgentStats a;
