from pydantic import BaseModel, Field
from typing import Optional, List
import uuid
from decimal import Decimal
from datetime import datetime
import random

class Equipment(BaseModel):
    ModelCode: str = Field(default="HO", description="Equipement model")
    Rate: str = Field(default="50.00", description="Base equipment rate")

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            Decimal: lambda v: str(v)
        }

class Itinerary(BaseModel):
    PickupDate:  Optional[str]
    DropoffDate:  Optional[str]
    PickupLocation:  Optional[str]
    DropoffLocation:  Optional[str]
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            Decimal: lambda v: str(v)
        }

class Order(BaseModel):
    OrderId: str = Field(default_factory=lambda: str(uuid.uuid4()))
    Status: str = Field(default="NEW", description="Record status")
    Equipment: Optional[List[Equipment]]
    TotalPaid: Optional[int] = Field(None, description="total paid")
    Type: Optional[str]=Field(None, description="type")
    Coverage: Optional[str]=Field(None, description="coverage")
    Itinerary: Optional[Itinerary]
    OrderType: Optional[str]=Field(None, description="order type")
    AssociatedContractId: Optional[str]=Field(None, description="associated contract id")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            Decimal: lambda v: str(v)
        }

class Job(BaseModel):
    job_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    job_type: Optional[str]
    job_status: Optional[str]
    rate_service_provider: Optional[str]
    total_paid: Optional[str]
    job_date_start: Optional[str]
    job_completed_date: Optional[str]
    job_entered_date: Optional[str]
    job_last_modified_date: Optional[str]
    service_provider_name: Optional[str]

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            Decimal: lambda v: str(v)
        }  



# ===== SAMPLE DATA GENERATORS =====

def generate_job_record() -> tuple[str, Job]:
    """Generate Job record"""
    statuses = ['Completed', 'New', 'Cancelled', 'Running']
    types = ["LoadUnload", "LoadOnly", "UnloadOnly"]
    key = f"job_{random.randint(100, 10000)}"
    return key, Job(
        job_id=key,
        job_type=random.choice(types),
        job_status=random.choice(statuses),
        rate_service_provider=f"{random.randint(10,150)}.0000",
        total_paid=f"{random.randint(10,150)}.0000",
        job_date_start=f"{datetime.now().strftime('%Y-%m-%d')}",
        job_completed_date=f"{datetime.now().strftime('%Y-%m-%d')}",
        job_entered_date=f"{datetime.now().strftime('%Y-%m-%d')}",
        job_last_modified_date=f"{datetime.now().strftime('%Y-%m-%d')}",
        service_provider_name=f"Provider {random.randint(1, 1000)}"
    )

def generate_truck_equipment() -> Equipment:
    truck_type= ['TRUCK_SMALL_10FT', 'TRUCK_MEDIUM_16FT', 'TRUCK_LARGE_26FT', 'TRUCK_EXTRA_LARGE_36FT', 'TRUCK_EXTRA_EXTRA_LARGE_46FT', 'TRUCK_EXTRA_EXTRA_EXTRA_LARGE_56FT']
    return Equipment(
        ModelCode=random.choice(truck_type),
        Rate=f"{random.randint(29,250)}.0000"
    )

def generate_moving_help_equipment() -> Equipment:
    moving_help_type= ['MOVING_BLANKETS', 'MOVING_BOXES', 'MOVING_PAPER', 'MOVING_OTHER']
    return Equipment(
        ModelCode=random.choice(moving_help_type),
        Rate=f"{random.randrange(9.95,19.95)}"
    )


def generate_order_record() -> Order:
    statuses = ['Return', 'Active', 'Completed', 'Cancelled', 'Pending']
    types = ['InTown', 'OutOfTown', 'OneWay']
    coverage = ['Full', 'Partial', 'None']
    payment = ['Cash', 'Credit Card', 'Debit Card']
    order_type = ['InTown', 'OutOfTown', 'OneWay']
    equipments = [generate_truck_equipment(), generate_moving_help_equipment()]
    itinerary = {'PickupDate': '2020-09-21T18:14:08.000Z', 'DropoffDate': '2020-09-21T20:47:42.000Z', 'PickupLocation': '41260', 'DropoffLocation': '41260'}
    key = f"order_{random.randint(100, 10000)}"
    o= Order(
        OrderId=key,
        Status=random.choice(statuses),
        Type=random.choice(types),
        Coverage=random.choice(coverage),
        Equipment=equipments,
        Itinerary=itinerary,
        Payment=random.choice(payment),
        OrderType=random.choice(order_type)
    )
    return key, o

