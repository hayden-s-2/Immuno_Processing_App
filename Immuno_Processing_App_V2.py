import streamlit as st
import numpy as np
import matplotlib.pyplot as plt
import cv2
import seaborn as sns
import pandas as pd
import io

from PIL import Image
from skimage.color import rgb2gray

st.title("Fluorescence Threshold Explorer")

# ── Session state ─────────────────────────────────────────────────────────────
if "current_index" not in st.session_state:
    st.session_state.current_index = 0
if "uploaded_file_names" not in st.session_state:
    st.session_state.uploaded_file_names = []

# ── File uploader ─────────────────────────────────────────────────────────────
uploaded_files = st.file_uploader(
    "Upload images (select multiple files from one folder)",
    type=["png", "jpg", "jpeg", "tif", "tiff"],
    accept_multiple_files=True,
)

if not uploaded_files:
    st.info("Upload one or more images to get started.")
    st.stop()

# Reset index whenever the file list changes
current_names = [f.name for f in uploaded_files]
if current_names != st.session_state.uploaded_file_names:
    st.session_state.uploaded_file_names = current_names
    st.session_state.current_index = 0

n_files = len(uploaded_files)
idx = st.session_state.current_index

# ── Navigation bar ────────────────────────────────────────────────────────────
st.markdown(f"### Image {idx + 1} of {n_files}: `{uploaded_files[idx].name}`")

nav_prev, nav_next, nav_spacer = st.columns([1, 1, 5])
with nav_prev:
    if st.button("⬅ Previous", disabled=(idx == 0), use_container_width=True):
        st.session_state.current_index -= 1
        st.rerun()
with nav_next:
    if st.button("Next ➡", disabled=(idx == n_files - 1), use_container_width=True):
        st.session_state.current_index += 1
        st.rerun()

# ── Load current image ────────────────────────────────────────────────────────
uploaded_file = uploaded_files[idx]
stem = uploaded_file.name.rsplit(".", 1)[0]   # filename without extension

image = np.array(Image.open(uploaded_file))

# Downscaled copy for display only
image_scale = 0.25
new_w = int(image.shape[1] * image_scale)
new_h = int(image.shape[0] * image_scale)
image_small = cv2.resize(image, (new_w, new_h), interpolation=cv2.INTER_AREA)

# ── Show original image ───────────────────────────────────────────────────────
st.subheader("Uploaded Image")
fig1, ax1 = plt.subplots()
ax1.imshow(image_small)
ax1.set_axis_off()
st.pyplot(fig1)
plt.close(fig1)

# ── Convert to grayscale ──────────────────────────────────────────────────────
if image.ndim == 3:
    image = rgb2gray(image)

image = image.astype(float)
if image.max() <= 1.0:
    image *= 255

# ── Threshold controls ────────────────────────────────────────────────────────
thresh_set_method = st.radio(
    "Select preferred method of setting threshold",
    ["Slider", "Text Input"],
)
threshold_slide = st.slider("Threshold", min_value=0, max_value=255, value=50)
threshold_text  = st.text_input("Enter threshold value (0–255)", "50")

if thresh_set_method == "Slider":
    threshold = float(threshold_slide)
else:
    try:
        threshold = float(threshold_text)
    except ValueError:
        st.warning("Invalid threshold value — defaulting to 50.")
        threshold = 50.0

# ── Binary mask & area fraction ───────────────────────────────────────────────
mask = image > threshold
area_fraction = mask.mean() * 100
st.write(f"**Percent above threshold:** {area_fraction:.2f}%")

profile_raw        = mask.mean(axis=0) * 100
profile_calibrated = np.nanmean(image, axis=0, where=mask)

# ── Mask ──────────────────────────────────────────────────────────────────────
st.subheader("Binary Mask")
fig2, ax2 = plt.subplots()
ax2.imshow(mask, cmap="gray")
ax2.set_axis_off()
st.pyplot(fig2)

# ── Cutting Off Image Edges ──────────────────────────────────────────────────────────────────────
extra = (image.shape[1] - 2000) % 3
if extra % 2 == 0:
    left_cut  = int(1000 + extra / 2)
    right_cut = int(1000 + extra / 2)
else:
    left_cut  = int(1000 + (extra / 2) + 0.5)
    right_cut = int(1000 + (extra / 2) - 0.5)

sets = np.round(np.linspace(left_cut, image.shape[1] - right_cut, 4), 0).astype(int)
set_spacing = sets[2] - sets[1]

# ── Area fraction profile ─────────────────────────────────────────────────────
st.subheader("Column-Wise Percent Above Threshold vs Distance")
fig3, ax3 = plt.subplots(figsize=(15, 7))
ax3_xvals = np.arange(left_cut, image.shape[1] - right_cut)
ax3_yvals = profile_raw[left_cut:(image.shape[1] - right_cut)]
ax3.plot(ax3_xvals, ax3_yvals, "o")
ax3.set_xticks(np.arange(1000, (image.shape[1] - right_cut) + 1000, 1000))
ax3.set_xlabel("Distance (pixels)")
ax3.set_ylabel("Percent Above Threshold")
ax3.set_title(f"Column-Wise Percent Above Threshold vs Distance (Threshold = {threshold:.0f})")
st.pyplot(fig3)

# # ── Calibrated mean gray value profile ───────────────────────────────────────
st.subheader("Column-Wise Mean Gray Value Accounting for Area Fraction")
fig4, ax4 = plt.subplots(figsize=(15, 7))
ax4_xvals = np.arange(left_cut, image.shape[1] - right_cut)
ax4_yvals = profile_calibrated[left_cut:(image.shape[1]-right_cut)]
ax4.plot(ax4_xvals, ax4_yvals, "o")
ax4.set_xticks(np.arange(1000, (image.shape[1] - right_cut) + 1000, 1000))
ax4.set_xlabel("Distance (pixels)")
ax4.set_ylabel("Calibrated Mean Gray Value")
ax4.set_title(f"Column-Wise Mean Gray Value Accounting for Area Fraction vs Distance (Threshold = {threshold:.0f})")
st.pyplot(fig4)

# ── Boxplots by image third ───────────────────────────────────────────────────
st.subheader("Boxplots of Mean Gray Value for Each Third of the Image")

set_numbers = np.concatenate([
    np.full(set_spacing, 1),
    np.full(set_spacing, 2),
    np.full(set_spacing, 3),
])

image_data_long = pd.DataFrame({
    "Image Third":           set_numbers,
    "Column Mean Gray Value": profile_calibrated[sets[0]:sets[0] + set_spacing * 3],
})

fig5, ax5 = plt.subplots(figsize=(11, 5))
sns.boxplot(
    data=image_data_long,
    x="Image Third",
    y="Column Mean Gray Value",
    hue="Image Third",
    palette="Set2",
    ax=ax5,
)
ax5.set_ylabel("Mean Gray Value")
ax5.set_title(f"Image Mean Gray Value by Thirds (Threshold = {threshold:.0f})")
st.pyplot(fig5)

# ── Download section ──────────────────────────────────────────────────────────
st.subheader("Download Results")
st.caption("Save any combination of outputs before moving to the next image.")

def fig_to_png_bytes(fig: plt.Figure) -> bytes:
    buf = io.BytesIO()
    fig.savefig(buf, format="png", bbox_inches="tight", dpi=150)
    buf.seek(0)
    return buf.read()

# Build CSV of column-wise data
csv_df = pd.DataFrame({
    "Column_Index":       np.arange(len(profile_raw)),
    "Area_Fraction_Pct":  np.round(profile_raw, 5),
    "Mean_Gray_Value":    np.round(profile_calibrated, 5)
})
csv_bytes = csv_df.to_csv(index=False).encode("utf-8")

dl1, dl2, dl3, dl4, dl5 = st.columns(5)

with dl1:
    st.download_button(
        "⬇ Mask",
        data=fig_to_png_bytes(fig2),
        file_name=f"{stem}_mask.png",
        mime="image/png",
        use_container_width=True,
    )

with dl2:
    st.download_button(
        "⬇ Area Fraction",
        data=fig_to_png_bytes(fig3),
        file_name=f"{stem}_area_fraction.png",
        mime="image/png",
        use_container_width=True,
    )

with dl3:
    st.download_button(
        "⬇ Mean Gray Value",
        data=fig_to_png_bytes(fig4),
        file_name=f"{stem}_mean_gray.png",
        mime="image/png",
        use_container_width=True,
    )

with dl4:
    st.download_button(
        "⬇ Boxplot",
        data=fig_to_png_bytes(fig5),
        file_name=f"{stem}_boxplot.png",
        mime="image/png",
        use_container_width=True,
    )

with dl5:
    st.download_button(
        "⬇ Raw Data (CSV)",
        data=csv_bytes,
        file_name=f"{stem}_data.csv",
        mime="text/csv",
        use_container_width=True,
    )

# Close figures to free memory
for fig in [fig2, fig3, fig4, fig5]:
    plt.close(fig)