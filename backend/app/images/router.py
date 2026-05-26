from fastapi import APIRouter, Depends, UploadFile, File, Query
from app.auth.dependencies import get_current_user
from app.images import service

router = APIRouter()


@router.post("/upload")
async def upload_image(
    file: UploadFile = File(...),
    is_main: bool = Query(False, description="Set as main profile photo"),
    user=Depends(get_current_user),
):
    return await service.upload_image(user["id"], file, is_main)


@router.get("/")
async def get_images(user=Depends(get_current_user)):
    return service.get_user_images(user["id"])


@router.patch("/{image_id}/set-main")
async def set_main(image_id: str, user=Depends(get_current_user)):
    return service.set_main_image(user["id"], image_id)


@router.delete("/{image_id}")
async def delete_image(image_id: str, user=Depends(get_current_user)):
    service.delete_image(user["id"], image_id)
    return {"message": "Image deleted"}


@router.post("/cover")
async def upload_cover(
    file: UploadFile = File(...),
    user=Depends(get_current_user),
):
    return await service.upload_cover_image(user["id"], file)


@router.delete("/cover")
async def delete_cover(user=Depends(get_current_user)):
    service.delete_cover_image(user["id"])
    return {"message": "Cover removed"}


@router.post("/verification")
async def upload_verification(
    file: UploadFile = File(...),
    user=Depends(get_current_user),
):
    return await service.upload_verification_selfie(user["id"], file)
